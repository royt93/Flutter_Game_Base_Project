import 'dart:async';

import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/clamped_clock.dart';

/// Energy/lives system that refills over time (Candy Crush-style "hearts").
///
/// Current energy is computed lazily from elapsed time since the last
/// baseline checkpoint, using [nowMsClamped] — **never** `DateTime.now()`
/// directly — so the same anti-cheat clamp `utils/clamped_clock.dart` gives
/// daily rewards/streaks also protects energy: winding the device clock
/// back can't farm free refills (see that file's doc comment for exactly
/// what the clamp does and doesn't defend against — a one-way forward jump
/// still isn't prevented, same as everywhere else that uses it).
class EnergyService extends GetxService {
  final int maxEnergy;
  final Duration refillInterval;

  EnergyService({
    this.maxEnergy = 5,
    this.refillInterval = const Duration(minutes: 30),
  });

  /// Gets the instance if already registered (safe to call from call sites
  /// that may run before/without energy registered, e.g. widget tests).
  static EnergyService? get maybe =>
      Get.isRegistered<EnergyService>() ? Get.find<EnergyService>() : null;

  /// Current energy, after crediting any whole refill ticks earned since
  /// the last checkpoint. Capped at [maxEnergy].
  int get currentEnergy {
    _regen();
    return StorageService.to.getInt(StorageKeys.energyCount, def: maxEnergy);
  }

  /// True while a [grantInfiniteLives] window is still active.
  bool get hasInfiniteLives =>
      StorageService.to.getInt(StorageKeys.energyInfiniteUntilMs, def: 0) >
      nowMsClamped();

  /// Consumes [amount] energy. Returns false — and deducts nothing — if
  /// there isn't enough. Always succeeds without deducting while
  /// [hasInfiniteLives] is active.
  bool consumeEnergy([int amount = 1]) {
    if (hasInfiniteLives) return true;
    _regen();

    final energy = StorageService.to.getInt(StorageKeys.energyCount, def: maxEnergy);
    if (energy < amount) return false;

    if (energy >= maxEnergy) {
      // Đầy tim trước khi trừ -> đây là lượt tiêu đầu tiên, bắt đầu tính giờ
      // hồi tim mới kể từ đúng thời điểm này (không dùng mốc cũ đã lỗi thời).
      unawaited(StorageService.to.setInt(StorageKeys.energyLastMs, nowMsClamped()));
    }
    unawaited(StorageService.to.setInt(StorageKeys.energyCount, energy - amount));
    return true;
  }

  /// Grants temporary unlimited energy for [duration] — `consumeEnergy`
  /// succeeds without deducting until it elapses.
  Future<void> grantInfiniteLives(Duration duration) => StorageService.to.setInt(
    StorageKeys.energyInfiniteUntilMs,
    nowMsClamped() + duration.inMilliseconds,
  );

  /// Credits whole refill ticks earned since the stored baseline. Leaves
  /// any leftover (sub-tick) progress toward the next point intact instead
  /// of resetting it, so reading [currentEnergy] repeatedly never costs
  /// partial progress.
  void _regen() {
    final energy = StorageService.to.getInt(StorageKeys.energyCount, def: maxEnergy);
    if (energy >= maxEnergy) return;

    final intervalMs = refillInterval.inMilliseconds;
    if (intervalMs <= 0) return;

    final now = nowMsClamped();
    final lastMs = StorageService.to.getInt(StorageKeys.energyLastMs, def: now);
    final ticks = (now - lastMs) ~/ intervalMs;
    if (ticks <= 0) return;

    var newEnergy = energy + ticks;
    if (newEnergy > maxEnergy) newEnergy = maxEnergy;
    final newLastMs = newEnergy >= maxEnergy ? now : lastMs + ticks * intervalMs;

    unawaited(StorageService.to.setInt(StorageKeys.energyCount, newEnergy));
    unawaited(StorageService.to.setInt(StorageKeys.energyLastMs, newLastMs));
  }
}
