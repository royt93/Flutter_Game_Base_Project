import 'dart:convert';

import 'replay_recorder.dart';
import 'save_integrity.dart';
import 'sdk_health_report.dart';
import 'utils/safe_json.dart';

/// Packages an [SdkHealthReport] snapshot (FEAT-39), a [ReplayCapsule]
/// (IDEA-42), a redacted config slice, and recent log lines into one
/// support-artifact JSON `Map` — `{schemaVersion, generatedAtMs,
/// appVersion, sections, errors, truncated}`.
///
/// **Deliberately does NOT accept a raw `StorageService.exportAll()` dump
/// as an ingredient** — that map has zero redaction (see
/// `storage_service.dart`), and this class's whole point is "safe to
/// paste into a support ticket by default". A future contributor wanting
/// to add a "storage" section must route it through the same
/// allowlist-by-name convention `config`/[HealthCollectorSpec] already
/// use here, not wire the raw dump straight through.
///
/// **Partial-failure contract**: each of the 4 sections is built behind
/// its own try/catch (an exception there is recorded in `errors[name]`,
/// never breaks the other 3), and if the assembled JSON exceeds
/// [maxBytes], sections are dropped — least-essential first (`logs`,
/// then `replay`, then `config`; `health` is kept as long as possible,
/// since it's the smallest/most triage-critical and already internally
/// capped by [SdkHealthReport]) — until it fits, each drop also recorded
/// in `errors` and `truncated` set to `true`. A partially-failed or
/// partially-dropped export is always still valid, parseable JSON with
/// whatever sections survived — never an all-or-nothing failure.
class DiagnosticsExportBundle {
  DiagnosticsExportBundle({
    this.maxBytes = defaultMaxBytes,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const int schemaVersion = 1;

  /// 200 KB — generous for a text/JSON support artifact meant to be
  /// pasted into a ticket or attached to an email, small enough that it
  /// never becomes its own bug report.
  static const int defaultMaxBytes = 200 * 1024;

  final int maxBytes;
  final int Function() _nowMs;

  /// Builds the bundle. `null` for [health]/[replay]/[config]/[logs] means
  /// "omit this section entirely" (distinct from an included-but-empty
  /// section, which [DiagnosticsBundleView] can tell apart).
  ///
  /// [configAllowedKeys] defaults to empty — same default-deny convention
  /// as [HealthCollectorSpec.allowedKeys]: passing a [config] map WITHOUT
  /// also naming which of its keys are safe to export produces an empty
  /// (not full) `config` section. A caller must opt keys in by name.
  Future<Map<String, Object?>> build({
    required String appVersion,
    SdkHealthReport? health,
    ReplayCapsule? replay,
    Map<String, Object?>? config,
    Set<String> configAllowedKeys = const {},
    List<String>? logs,
    int maxLogLines = 200,
    int maxLogLineLength = 500,
  }) async {
    final sections = <String, Object?>{};
    final errors = <String, String>{};

    if (health != null) {
      try {
        sections['health'] = await health.collect();
      } catch (_) {
        errors['health'] = 'collector failed';
      }
    }

    if (replay != null) {
      try {
        sections['replay'] = replay.toJson();
      } catch (_) {
        errors['replay'] = 'serialize failed';
      }
    }

    if (config != null) {
      try {
        sections['config'] = {
          for (final entry in config.entries)
            if (configAllowedKeys.contains(entry.key)) entry.key: entry.value,
        };
      } catch (_) {
        errors['config'] = 'redact failed';
      }
    }

    if (logs != null) {
      try {
        final tail = logs.length > maxLogLines
            ? logs.sublist(logs.length - maxLogLines)
            : logs;
        sections['logs'] = [
          for (final line in tail)
            line.length > maxLogLineLength
                ? '${line.substring(0, maxLogLineLength)}…(truncated)'
                : line,
        ];
      } catch (_) {
        errors['logs'] = 'capture failed';
      }
    }

    var truncated = false;
    for (final key in const ['logs', 'replay', 'config']) {
      if (_byteSize(sections, errors) <= maxBytes) break;
      if (sections.remove(key) != null) {
        truncated = true;
        errors[key] = 'dropped: bundle size cap exceeded';
      }
    }
    if (_byteSize(sections, errors) > maxBytes) {
      truncated = true;
      errors['bundle'] =
          'still exceeds size cap after dropping every optional section';
    }

    return {
      'schemaVersion': schemaVersion,
      'generatedAtMs': _nowMs(),
      'appVersion': appVersion,
      'sections': sections,
      'errors': errors,
      'truncated': truncated,
    };
  }

  int _byteSize(Map<String, Object?> sections, Map<String, String> errors) =>
      utf8.encode(jsonEncode({'sections': sections, 'errors': errors})).length;

  /// Signs [bundle] (the `Map` [build] returned) via HMAC —
  /// `save_integrity.dart`'s own `signExport`, same convention
  /// `ReplayCapsule.exportSigned` already uses, so this bundle's checksum
  /// works exactly like every other signed artifact in this package.
  Map<String, Object?> sign(Map<String, Object?> bundle, String secret) =>
      signExport(bundle, secret);
}

/// Read-only parsed view of an exported bundle. Parsing NEVER writes to
/// `StorageService` or any registered service — this is FEAT-70's "import
/// chỉ read-only" contract: opening a diagnostics bundle a player/QA sent
/// you can never mutate your own app's state, unlike `VersionedJsonStore`
/// import (which is meant to restore state) or `StorageService.importAll`.
class DiagnosticsBundleView {
  const DiagnosticsBundleView._(this._raw);

  final Map<String, Object?> _raw;

  /// Returns `null` (never throws) on a missing/malformed shape — same
  /// defensive convention as [ReplayCapsule.fromJsonUnsigned].
  static DiagnosticsBundleView? fromJson(Map<String, Object?> json) {
    if (json['sections'] is! Map) return null;
    return DiagnosticsBundleView._(json);
  }

  /// Verifies the HMAC via [verifyAndStrip] — throws [FormatException] on
  /// a missing/mismatched checksum, that function's own contract — then
  /// parses; returns `null` if the checksum is fine but the shape isn't.
  static DiagnosticsBundleView? fromSignedJson(
    Map<String, Object?> signedJson,
    String secret,
  ) {
    final data = verifyAndStrip(signedJson, secret);
    return fromJson(data);
  }

  int get schemaVersion => asIntOr(_raw['schemaVersion'], 0);
  int get generatedAtMs => asIntOr(_raw['generatedAtMs'], 0);
  String get appVersion => asStringOr(_raw['appVersion'], '');
  bool get truncated => _raw['truncated'] == true;

  Map<String, String> get errors {
    final raw = _raw['errors'];
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): asStringOr(entry.value, ''),
    };
  }

  Map<String, Object?>? get health => _section('health');
  Map<String, Object?>? get replay => _section('replay');
  Map<String, Object?>? get config => _section('config');

  List<String>? get logs {
    final raw = (_raw['sections'] as Map?)?['logs'];
    if (raw is! List) return null;
    return raw.map((e) => asStringOr(e, '')).toList();
  }

  Map<String, Object?>? _section(String name) {
    final raw = (_raw['sections'] as Map?)?[name];
    return raw is Map ? Map<String, Object?>.from(raw) : null;
  }
}
