import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:get/get.dart';

import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

/// Remote config / feature-flag seam. The package pulls in no HTTP/Firebase
/// SDK — a consuming app injects its own network call via [fetchRemote]
/// (e.g. wrapping `dio`/`http`/Firebase Remote Config). [init] always loads
/// the bundled asset fallback first so typed getters have something valid
/// to return even before (or if) the network attempt resolves, then tries
/// [fetchRemote] and overrides the in-memory config on success. A missing
/// asset or a failing/absent [fetchRemote] is swallowed silently — this
/// never throws, it just falls back to defaults.
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

  /// Null-safe accessor for call sites that may run before/without this
  /// service registered (mirrors [AudioManager.maybe]).
  static RemoteConfigService? get maybe =>
      Get.isRegistered<RemoteConfigService>()
      ? Get.find<RemoteConfigService>()
      : null;

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
      _config = await fetch();
    } catch (_) {
      // Network fetch failed → silently keep the asset fallback.
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
