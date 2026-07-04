import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/achievements.dart';
import 'game_controller.dart';

/// Theo dõi tiến trình thành tựu + cho nhận thưởng xu (offline).
class AchievementController extends GetxController {
  final GameController g;
  AchievementController(this.g);

  final StorageService _store = StorageService.to;

  /// id thành tựu đã nhận thưởng (reactive cho UI/badge).
  final RxSet<String> claimed = <String>{}.obs;

  /// W18.2: id thành tựu đang ĐEO làm DANH HIỆU (hiện ở Home), '' = không đeo.
  final RxString equippedTitle = ''.obs;

  static AchievementController? get maybe =>
      Get.isRegistered<AchievementController>()
      ? Get.find<AchievementController>()
      : null;

  /// Xoá cờ "đã nhận" + danh hiệu đeo in-memory khi reset (controller permanent).
  void resetState() {
    claimed.clear();
    equippedTitle.value = '';
  }

  @override
  void onInit() {
    super.onInit();
    for (final a in kAchievements) {
      if (_store.getInt(StorageKeys.achievementClaimed(a.id)) == 1) {
        claimed.add(a.id);
      }
    }
    final stored = _store.getString(StorageKeys.equippedTitle) ?? '';
    // M6 fix: chỉ nhận danh hiệu hợp lệ (id phải có trong claimed).
    // Chống trường hợp đĩa lưu id nhưng achievement bị xoá khỏi kAchievements.
    if (stored.isNotEmpty && claimed.contains(stored)) {
      equippedTitle.value = stored;
    } else if (stored.isNotEmpty) {
      unawaited(_store.remove(StorageKeys.equippedTitle)); // dọn đĩa cũ
    }
  }

  /// W18.2: đeo danh hiệu của thành tựu [id] (chỉ khi ĐÃ nhận). Đeo lại cái đang
  /// đeo → gỡ (toggle). Trả true nếu đổi trạng thái.
  bool equipTitle(String id) {
    if (!claimed.contains(id)) return false;
    final unequip = equippedTitle.value == id;
    equippedTitle.value = unequip ? '' : id;
    // Gỡ → remove key thay vì setString('') để nhất quán với pattern resetProgress.
    if (unequip) {
      unawaited(_store.remove(StorageKeys.equippedTitle));
    } else {
      unawaited(_store.setString(StorageKeys.equippedTitle, id));
    }
    return true;
  }

  /// Key i18n của danh hiệu đang đeo (null nếu không đeo). Dùng cho Home/Versus.
  String? get equippedTitleKey {
    if (equippedTitle.value.isEmpty) return null;
    return 'ach_${equippedTitle.value}_t';
  }

  /// Giá trị hiện tại của chỉ số thành tựu đang theo dõi.
  int currentValue(AchStat s) {
    switch (s) {
      case AchStat.totalWins:
        return g.totalWins.value;
      case AchStat.totalStars:
        return g.totalStars;
      case AchStat.bestCombo:
        return g.bestCombo.value;
      case AchStat.bestWinStreak:
        return g.bestWinStreak.value;
      case AchStat.unlockedLevel:
        return g.unlockedLevel.value;
      case AchStat.coinsEarned:
        return g.coinsEarnedTotal.value;
      case AchStat.clanContribTotal:
        return g.clanContribLifetime.value;
      case AchStat.platinumMilestones:
        return g.platinumMilestonesCount;
    }
  }

  bool isUnlocked(Achievement a) => currentValue(a.stat) >= a.threshold;
  bool isClaimed(Achievement a) => claimed.contains(a.id);
  bool canClaim(Achievement a) => isUnlocked(a) && !isClaimed(a);

  /// Có thành tựu nào đã đạt mà chưa nhận (cho badge Home)?
  bool get hasUnclaimed => kAchievements.any(canClaim);

  double progress(Achievement a) =>
      (currentValue(a.stat) / a.threshold).clamp(0.0, 1.0);

  /// Nhận thưởng. Trả về xu nhận (0 nếu không đủ điều kiện).
  int claim(Achievement a) {
    if (!canClaim(a)) return 0;
    // Ghi cờ "đã nhận" TRƯỚC khi cộng xu → chặn nhận thưởng 2 lần.
    claimed.add(a.id);
    unawaited(_store.setInt(StorageKeys.achievementClaimed(a.id), 1));
    g.addCoins(a.reward);
    return a.reward;
  }
}
