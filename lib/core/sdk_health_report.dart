import 'dart:async';
import 'dart:convert';

import 'app_info.dart';
import 'audio_manager.dart';
import 'performance_tier_service.dart';
import 'remote_config_service.dart';
import 'replay_recorder.dart';

/// One named section of an [SdkHealthReport] — [collect] gathers whatever
/// diagnostic data this section wants, and [allowedKeys] is the ONLY thing
/// that actually reaches the report: any key [collect] returns that isn't
/// in [allowedKeys] is silently dropped, never the other way around
/// (default-deny, not default-allow) — a collector that starts returning
/// one extra field by mistake (or a copy-pasted `token`/`secret` key)
/// can't leak it into a report a QA/support person might screenshot or
/// paste into a ticket.
class HealthCollectorSpec {
  const HealthCollectorSpec({
    required this.name,
    required this.allowedKeys,
    required this.collect,
  });

  final String name;
  final Set<String> allowedKeys;
  final FutureOr<Map<String, Object?>> Function() collect;
}

/// Collects a QA/support-facing diagnostic snapshot from whichever
/// [HealthCollectorSpec]s are registered — a missing or throwing collector
/// never breaks the rest of the report (its section just reports `_error`
/// instead), and every value is redacted to its own allowlist and size-
/// capped, so this is safe to export/copy/share by default (no secret,
/// raw save data, token, or PII shows up unless a collector's own
/// allowlist explicitly names that key — which none of this package's own
/// [defaultHealthCollectors] do).
class SdkHealthReport {
  SdkHealthReport({
    this.timeout = const Duration(milliseconds: 500),
    int Function()? nowMs,
    this.maxStringLength = 500,
    this.maxListLength = 50,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const schemaVersion = 1;

  final Duration timeout;
  final int Function() _nowMs;
  final int maxStringLength;
  final int maxListLength;
  final _collectors = <HealthCollectorSpec>[];

  void register(HealthCollectorSpec spec) => _collectors.add(spec);

  void registerAll(Iterable<HealthCollectorSpec> specs) =>
      _collectors.addAll(specs);

  /// Runs every registered collector (each isolated behind its own
  /// [timeout] + try/catch) and returns the aggregate — a plain,
  /// JSON-encodable `Map` (`{schemaVersion, generatedAtMs, sections}`).
  Future<Map<String, Object?>> collect() async {
    final sections = <String, Object?>{};
    for (final spec in _collectors) {
      sections[spec.name] = await _collectOne(spec);
    }
    return {
      'schemaVersion': schemaVersion,
      'generatedAtMs': _nowMs(),
      'sections': sections,
    };
  }

  Future<String> collectJson() async =>
      const JsonEncoder.withIndent('  ').convert(await collect());

  Future<Map<String, Object?>> _collectOne(HealthCollectorSpec spec) async {
    try {
      final raw = await Future.sync(spec.collect).timeout(timeout);
      return _redactAndCap(raw, spec.allowedKeys);
    } catch (error) {
      return {
        '_error': error is TimeoutException ? 'timeout' : 'collector failed',
      };
    }
  }

  Map<String, Object?> _redactAndCap(
    Map<String, Object?> raw,
    Set<String> allowedKeys,
  ) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      if (!allowedKeys.contains(entry.key)) continue;
      out[entry.key] = _cap(entry.value);
    }
    return out;
  }

  Object? _cap(Object? value) {
    if (value is String && value.length > maxStringLength) {
      return '${value.substring(0, maxStringLength)}…(truncated)';
    }
    if (value is List && value.length > maxListLength) {
      return [
        ...value.take(maxListLength),
        '…(${value.length - maxListLength} more)',
      ];
    }
    return value;
  }
}

/// This package's own built-in collectors — one per module named in
/// FEAT-39's sprint slice (app version, FPS/performance tier, audio,
/// config source, replay buffer). Each reports `registered: false` (never
/// an error) when its module isn't `Get.put` in this app, since "not
/// wired up" isn't a health PROBLEM this report should flag.
List<HealthCollectorSpec> defaultHealthCollectors() => [
  HealthCollectorSpec(
    name: 'app',
    allowedKeys: const {'version', 'buildNumber', 'packageName'},
    collect: () => {
      'version': kAppVersion,
      'buildNumber': kAppBuildNumber,
      'packageName': kPackageName,
    },
  ),
  HealthCollectorSpec(
    name: 'audio',
    allowedKeys: const {'registered', 'muted'},
    collect: () {
      final audio = AudioManager.maybe;
      return {
        'registered': audio != null,
        if (audio != null) 'muted': audio.muted.value,
      };
    },
  ),
  HealthCollectorSpec(
    name: 'performance',
    allowedKeys: const {'registered', 'tier'},
    collect: () {
      final perf = PerformanceTierService.maybe;
      return {
        'registered': perf != null,
        if (perf != null) 'tier': perf.tier.value.name,
      };
    },
  ),
  HealthCollectorSpec(
    name: 'remoteConfig',
    allowedKeys: const {'registered', 'source'},
    collect: () {
      final config = RemoteConfigService.maybe;
      return {
        'registered': config != null,
        if (config != null) 'source': config.source.name,
      };
    },
  ),
  HealthCollectorSpec(
    name: 'replayBuffer',
    allowedKeys: const {'registered', 'eventCount', 'isRecording'},
    collect: () {
      final recorder = ReplayRecorder.maybe;
      return {
        'registered': recorder != null,
        if (recorder != null) 'eventCount': recorder.eventCount,
        if (recorder != null) 'isRecording': recorder.isRecording,
      };
    },
  ),
];
