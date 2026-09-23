import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:get/get.dart';

import 'sdk_event_schema_registry.dart' show EventParamType;
import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

/// One remote-config key's expected shape — registered via
/// [RemoteConfigService]'s `schema` constructor param (ENH-84). Reuses
/// [EventParamType] (`SdkEventSchemaRegistry`'s own 4 primitive kinds) —
/// remote config values are the exact same string/int/double/bool shapes,
/// no need for a parallel type enum.
class RemoteConfigKeySchema {
  const RemoteConfigKeySchema({required this.type, this.required = false});

  final EventParamType type;

  /// If `true`, [key] missing from the merged config entirely (not just
  /// wrong-typed) is itself a violation — most remote-config keys are
  /// meant to be optional (a missing key just means "use the getter's own
  /// `fallback` param"), so this defaults to `false`.
  final bool required;
}

bool _matchesConfigType(Object? value, EventParamType type) => switch (type) {
  EventParamType.string => value is String,
  EventParamType.int => value is int,
  EventParamType.double => value is double || value is int,
  EventParamType.bool => value is bool,
};

/// Where [RemoteConfigService]'s current config actually came from —
/// exposed alongside [RemoteConfigService.snapshot] so a caller/test can
/// tell "still asset-only" apart from "remote merged in" without having to
/// diff key values (ENH-58).
enum RemoteConfigSource {
  /// [RemoteConfigService.fetchRemote] was never provided, or [init] hasn't
  /// run yet — config is exactly whatever the bundled asset had (or empty).
  assetOnly,

  /// [RemoteConfigService.fetchRemote] resolved at least once and its
  /// non-null entries were merged in on top of the asset defaults.
  remoteMerged,

  /// [RemoteConfigService.fetchRemote] was provided but threw — config
  /// stayed at whatever it was before the attempt (asset-only, or a
  /// previous successful merge).
  remoteFailed,
}

/// Remote config / feature-flag seam. The package pulls in no HTTP/Firebase
/// SDK — a consuming app injects its own network call via [fetchRemote]
/// (e.g. wrapping `dio`/`http`/Firebase Remote Config). [init] always loads
/// the bundled asset fallback first so typed getters have something valid
/// to return even before (or if) the network attempt resolves, then tries
/// [fetchRemote] and MERGES its entries on top of the asset defaults
/// key-by-key (ENH-58) — a partial response only overrides the keys it
/// actually sends, every other key keeps its already-validated asset
/// value. A `null` value for a key in the remote response is treated as
/// "no override" (skipped) rather than "set this key to null", so a
/// server that echoes back unset fields as `null` can't wipe a working
/// default. A missing asset or a failing/absent [fetchRemote] is
/// swallowed silently — this never throws, it just falls back to
/// defaults.
class RemoteConfigService extends GetxService {
  RemoteConfigService({
    required String assetPath,
    this.fetchRemote,
    AssetBundle? bundle,
    this.schema = const {},
  }) : _assetPath = assetPath,
       _bundle = bundle ?? rootBundle;

  final String _assetPath;
  final AssetBundle _bundle;
  final Future<Map<String, Object?>> Function()? fetchRemote;

  /// Expected shape for any subset of remote-config keys (ENH-84) — left
  /// at its default `{}` (no key registered), [init]/[initResult] behave
  /// EXACTLY as before this param existed: fully backward compatible.
  final Map<String, RemoteConfigKeySchema> schema;

  Map<String, Object?> _config = const {};
  RemoteConfigSource _source = RemoteConfigSource.assetOnly;
  List<String> _schemaViolations = const [];

  /// Null-safe accessor for call sites that may run before/without this
  /// service registered (mirrors [AudioManager.maybe]).
  static RemoteConfigService? get maybe =>
      Get.isRegistered<RemoteConfigService>()
      ? Get.find<RemoteConfigService>()
      : null;

  /// Read-only view of the current merged config (ENH-58) — a defensive
  /// copy, so a caller can't mutate this service's internal state by
  /// holding onto and modifying the returned map.
  Map<String, Object?> get snapshot => Map.unmodifiable(_config);

  /// Where [snapshot]'s current contents actually came from (ENH-58).
  RemoteConfigSource get source => _source;

  /// Violations found against [schema] the last time [init] ran — always
  /// empty when [schema] is empty (the default) or when the merged config
  /// matched it completely. [init] itself never throws on these (same
  /// never-throws contract as always); [initResult] is what turns a
  /// non-empty list into a reportable [SdkFailure].
  List<String> get schemaViolations => List.unmodifiable(_schemaViolations);

  Future<void> init() async {
    try {
      final raw = await _bundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _config = decoded.cast<String, Object?>();
      }
    } catch (_) {
      // No bundled asset (or invalid JSON) → keep the empty config; getters
      // fall back to their own defaults instead of crashing.
    }

    final fetch = fetchRemote;
    if (fetch == null) {
      _schemaViolations = _validateSchema();
      return;
    }
    try {
      final remote = await fetch();
      // ENH-58: merge, don't replace — a partial (or even empty) response
      // must not wipe asset-default keys it simply didn't mention. A `null`
      // entry is treated as "no override" for that key (see class doc).
      _config = {
        ..._config,
        for (final entry in remote.entries)
          if (entry.value != null) entry.key: entry.value,
      };
      _source = RemoteConfigSource.remoteMerged;
    } catch (_) {
      // Network fetch failed → silently keep whatever config we had before
      // this attempt (asset-only, or a previous successful merge).
      _source = RemoteConfigSource.remoteFailed;
    }
    _schemaViolations = _validateSchema();
  }

  /// Checks the current [_config] against [schema] (ENH-84) — a key
  /// [RemoteConfigKeySchema.required] but entirely missing, or present
  /// with the wrong runtime type, is 1 violation each; a key [schema]
  /// doesn't mention at all is never a violation (this is a validation
  /// layer, not a strict allowlist — unlike `SdkEventSchemaRegistry`'s
  /// event params, an unlisted remote-config key is completely normal).
  List<String> _validateSchema() {
    if (schema.isEmpty) return const [];
    final violations = <String>[];
    for (final entry in schema.entries) {
      final key = entry.key;
      final keySchema = entry.value;
      if (!_config.containsKey(key)) {
        if (keySchema.required) {
          violations.add('thiếu key bắt buộc "$key"');
        }
        continue;
      }
      final value = _config[key];
      if (!_matchesConfigType(value, keySchema.type)) {
        violations.add(
          'key "$key" sai type (cần ${keySchema.type.name}, nhận '
          '${value.runtimeType})',
        );
      }
    }
    return violations;
  }

  /// Unlike [init] (which never throws — a fetch failure just falls back
  /// to defaults, see the class doc), this DOES surface a failed remote
  /// fetch as an [SdkFailure] — a caller that wants to know "did boot
  /// actually succeed" shouldn't have to separately check [source] to
  /// notice the difference between "remote merged" and "silently fell
  /// back". [init] itself is unaffected: it still never throws and still
  /// sets [source] exactly as before — this only changes what
  /// [initResult] REPORTS about that outcome.
  Future<SdkResult<void>> initResult() async {
    try {
      await init();
    } catch (error, stack) {
      // init() is documented never-throws, but this stays defensive in
      // case a future edit there breaks that contract — still reported as
      // the same kind of failure a fetch failure would be.
      return SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Remote configuration unavailable',
        retryable: true,
        cause: error,
        stackTrace: stack,
      );
    }
    if (_source == RemoteConfigSource.remoteFailed) {
      return const SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Remote configuration fetch failed, using fallback config',
        retryable: true,
      );
    }
    if (_schemaViolations.isNotEmpty) {
      // ENH-84: caught centrally here instead of at whatever call site
      // eventually reads the wrong-typed key — lists every violating key
      // by name so a misconfigured CMS/server value is diagnosable from
      // this single result, not from a stack trace deep inside game logic.
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message:
            'Remote configuration failed schema validation: '
            '${_schemaViolations.join('; ')}',
        retryable: false,
      );
    }
    return const SdkSuccess(null);
  }

  String getString(String key, {String fallback = ''}) =>
      asStringOr(_config[key], fallback);

  int getInt(String key, {int fallback = 0}) => asIntOr(_config[key], fallback);

  double getDouble(String key, {double fallback = 0}) =>
      asDoubleOr(_config[key], fallback);

  bool getBool(String key, {bool fallback = false}) =>
      asBoolOr(_config[key], fallback);
}
