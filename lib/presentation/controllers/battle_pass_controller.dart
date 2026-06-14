import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/battle_pass.dart';
import 'game_controller.dart';

/// Battle Pass + nhiệm vụ ngày (Wave 7, offline).
/// - 3 quest/ngày (xác định theo epoch-day) → hoàn thành cộng XP.
/// - XP đẩy cấp pass; mỗi cấp 1 phần thưởng nhận 1 lần.
class BattlePassController extends GetxController {
  final GameController g;
  BattlePassController(this.g);

  final StorageService _store = StorageService.to;

  final RxInt xp = 0.obs;
  final RxSet<int> claimed = <int>{}.obs; // index tier đã nhận

  /// Tiến trình 3 quest hôm nay + cờ đã-cộng-XP.
  final RxList<int> questProgress = <int>[0, 0, 0].obs;
  final List<bool> _credited = [false, false, false];
  late List<QuestTemplate> todayQuests;
  int _questDay = -1;

  static BattlePassController? get maybe => Get.isRegistered<BattlePassController>()
      ? Get.find<BattlePassController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    xp.value = _store.getInt(StorageKeys.bpXp, def: 0);
    for (int i = 0; i < kPassTiers.length; i++) {
      if (_store.getInt(StorageKeys.bpClaimed(i)) == 1) claimed.add(i);
    }
    _loadQuests();
  }

  void _loadQuests() {
    final today = g.todayEpochDay;
    todayQuests = dailyQuests(today);
    final saved = _store.getInt(StorageKeys.questDay, def: -1);
    _questDay = today;
    if (saved != today) {
      // sang ngày mới → reset tiến trình
      questProgress.value = [0, 0, 0];
      for (int i = 0; i < 3; i++) {
        _credited[i] = false;
        unawaited(_store.setInt(StorageKeys.questProgress(i), 0));
        unawaited(_store.setInt(StorageKeys.questCredited(i), 0));
      }
      unawaited(_store.setInt(StorageKeys.questDay, today));
    } else {
      for (int i = 0; i < 3; i++) {
        questProgress[i] = _store.getInt(StorageKeys.questProgress(i), def: 0);
        _credited[i] = _store.getInt(StorageKeys.questCredited(i)) == 1;
      }
    }
  }

  /// Cấp pass hiện tại = số tier có ngưỡng XP <= xp.
  int get level => kPassTiers.where((t) => xp.value >= t.xpNeeded).length;

  bool isReached(int idx) => idx < level;
  bool isClaimed(int idx) => claimed.contains(idx);
  bool canClaim(int idx) => isReached(idx) && !isClaimed(idx);
  bool get hasClaimable =>
      List.generate(kPassTiers.length, (i) => i).any(canClaim);

  bool questDone(int i) =>
      i < todayQuests.length && questProgress[i] >= todayQuests[i].target;

  /// XP còn thiếu để lên cấp kế (0 nếu đã max).
  int get xpToNext {
    if (level >= kPassTiers.length) return 0;
    return kPassTiers[level].xpNeeded - xp.value;
  }

  void _addXp(int n) {
    if (n <= 0) return;
    xp.value += n;
    unawaited(_store.setInt(StorageKeys.bpXp, xp.value));
  }

  /// Gọi khi 1 màn kết thúc (từ GameScreenController). Endless KHÔNG tính
  /// (tránh farm). Cập nhật tiến trình 3 quest + cộng XP khi quest xong.
  void recordLevelEnd({
    required bool win,
    required int stars,
    required int coins,
    required int combo,
  }) {
    _ensureToday();
    for (int i = 0; i < todayQuests.length; i++) {
      final q = todayQuests[i];
      int p = questProgress[i];
      switch (q.type) {
        case QuestType.winLevels:
          if (win) p += 1;
          break;
        case QuestType.playLevels:
          p += 1;
          break;
        case QuestType.earnCoins:
          if (win) p += coins;
          break;
        case QuestType.collectStars:
          if (win) p += stars;
          break;
        case QuestType.reachCombo:
          if (combo > p) p = combo; // "đạt combo" → giữ giá trị cao nhất
          break;
      }
      if (p != questProgress[i]) {
        questProgress[i] = p;
        unawaited(_store.setInt(StorageKeys.questProgress(i), p));
      }
      // hoàn thành lần đầu → cộng XP
      if (!_credited[i] && p >= q.target) {
        _credited[i] = true;
        unawaited(_store.setInt(StorageKeys.questCredited(i), 1));
        _addXp(q.xp);
      }
    }
  }

  void _ensureToday() {
    if (_questDay != g.todayEpochDay) _loadQuests();
  }

  /// Nhận thưởng tier [idx]. Trả về true nếu nhận được.
  bool claim(int idx) {
    if (!canClaim(idx)) return false;
    claimed.add(idx);
    unawaited(_store.setInt(StorageKeys.bpClaimed(idx), 1));
    final t = kPassTiers[idx];
    switch (t.kind) {
      case RewardKind.coins:
        g.addCoins(t.amount);
        break;
      case RewardKind.shards:
        g.addShards(t.amount);
        break;
      case RewardKind.hammer:
        g.grantHammer(t.amount);
        break;
      case RewardKind.moves:
        g.grantMovesBooster(t.amount);
        break;
    }
    return true;
  }
}
