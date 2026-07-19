import 'package:get/get.dart';

import '../../core/storage_service.dart';
import '../../data/boss_rush.dart';
import '../../data/levels.dart';
import '../../data/worlds.dart';
import 'game_controller.dart';

/// I43: điều phối 1 lượt Boss Rush (chuỗi bàn boss liên tiếp) — tách biệt
/// khỏi [GameController] để tránh phụ thuộc vòng (xem ghi chú kiến trúc ở
/// `boss_rush.dart`/plan I43): [GameController] chỉ có 2 method nhỏ
/// (`startBossRush`/`setBossRushLevel`), không biết gì về controller này.
/// [PopStarGame] là nơi gọi [advanceStage] khi thắng 1 bàn.
class BossRushController extends GetxController {
  static const int startingLives = 1;

  final stage = 1.obs;
  final bossRushBestStreak = 0.obs;
  final livesRemaining = startingLives.obs;

  /// Kết quả lượt gần nhất — hiển thị ở màn tóm tắt lobby sau khi kết thúc.
  int lastCoinReward = 0;
  int lastStagesCleared = 0;

  Worker? _endWorker;

  @override
  void onInit() {
    super.onInit();
    bossRushBestStreak.value = StorageService.to.getInt(
      StorageKeys.bossRushBestStreak,
    );
    _endWorker = ever(Get.find<GameController>().ended, _onEnded);
  }

  @override
  void onClose() {
    _endWorker?.dispose();
    super.onClose();
  }

  int get maxUnlockedWorld =>
      ((Get.find<GameController>().unlockedLevel.value - 1) ~/ 20).clamp(
        0,
        kWorlds.length - 1,
      );

  void startRun() {
    stage.value = 1;
    livesRemaining.value = startingLives;
    Get.find<GameController>().startBossRush(
      bossRushLevelForStage(1, maxUnlockedWorld),
    );
  }

  /// Gọi từ [PopStarGame] khi 1 bàn được dọn sạch — tăng stage, trả bàn kế.
  PopLevel advanceStage() {
    stage.value++;
    final level = bossRushLevelForStage(stage.value, maxUnlockedWorld);
    Get.find<GameController>().setBossRushLevel(level);
    return level;
  }

  void _onEnded(bool ended) {
    if (!ended) return;
    if (Get.find<GameController>().mode.value != GameMode.bossRush) return;
    _endRun();
  }

  void _endRun() {
    final gameCtrl = Get.find<GameController>();
    final clearedStages = stage.value - 1;
    if (clearedStages > bossRushBestStreak.value) {
      bossRushBestStreak.value = clearedStages;
      StorageService.to.setInt(StorageKeys.bossRushBestStreak, clearedStages);
    }
    final coinReward = stage.value * 50;
    gameCtrl.coins.value += coinReward;
    StorageService.to.setInt(StorageKeys.coins, gameCtrl.coins.value);
    lastCoinReward = coinReward;
    lastStagesCleared = clearedStages;
  }
}
