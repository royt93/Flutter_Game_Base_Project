import 'dart:async';

import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'debug_log.dart';
import 'storage_service.dart';

/// Keeps the screen from auto-locking while [enabled] — wraps `wakelock_plus`
/// with a persisted on/off preference (`StorageKeys.wakeLockEnabled`), the
/// same shape as [AudioManager]'s `muted` flag, so a consuming app can expose
/// its own settings toggle instead of the kit unconditionally forcing the
/// screen to stay on.
///
/// Defaults to `true` on first install (opt-out, not opt-in) — the classic
/// casual-game expectation is that gameplay keeps the screen awake unless the
/// player turns it off, matching what most casual/idle games ship with out of
/// the box.
class WakeLockService extends GetxService {
  final RxBool enabled = true.obs;

  /// Null-safe accessor for call sites that may run before/without this
  /// service registered (mirrors [AudioManager.maybe]).
  static WakeLockService? get maybe =>
      Get.isRegistered<WakeLockService>() ? Get.find<WakeLockService>() : null;

  /// Restores the saved preference and applies it to the real platform
  /// wakelock. Never throws — a platform with no wakelock support (e.g. some
  /// test environments) just leaves the screen's own timeout behavior alone.
  Future<void> init() async {
    enabled.value = StorageService.to.getBool(
      StorageKeys.wakeLockEnabled,
      def: true,
    );
    await _apply(enabled.value);
  }

  Future<void> setEnabled(bool value) async {
    if (enabled.value == value) return;
    enabled.value = value;
    unawaited(StorageService.to.setBool(StorageKeys.wakeLockEnabled, value));
    await _apply(value);
  }

  Future<void> toggle() => setEnabled(!enabled.value);

  Future<void> _apply(bool value) async {
    try {
      await WakelockPlus.toggle(enable: value);
    } catch (e) {
      dlog('WakeLockService: toggle($value) failed: $e');
    }
  }

  @override
  void onClose() {
    // Best-effort: release the wakelock so a non-permanent registration
    // (e.g. a test tearing down) never leaves the screen forced awake.
    unawaited(WakelockPlus.disable().catchError((_) {}));
    super.onClose();
  }
}
