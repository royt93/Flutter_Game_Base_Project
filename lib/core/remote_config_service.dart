import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:get/get.dart';

import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

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
  }) : _assetPath = assetPath,
       _bundle = bundle ?? rootBundle;

  final String _assetPath;
  final AssetBundle _bundle;
  final Future<Map<String, Object?>> Function()? fetchRemote;

  Map<String, Object?> _config = const {};
  RemoteConfigSource _source = RemoteConfigSource.assetOnly;

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
    if (fetch == null) return;
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
  }

  Future<SdkResult<void>> initResult() async {
    try {
      await init();
      return const SdkSuccess(null);
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Remote configuration unavailable',
        retryable: true,
        cause: error,
        stackTrace: stack,
      );
    }
  }

  String getString(String key, {String fallback = ''}) =>
      asStringOr(_config[key], fallback);

  int getInt(String key, {int fallback = 0}) => asIntOr(_config[key], fallback);

  double getDouble(String key, {double fallback = 0}) =>
      asDoubleOr(_config[key], fallback);

  bool getBool(String key, {bool fallback = false}) =>
      asBoolOr(_config[key], fallback);
}
