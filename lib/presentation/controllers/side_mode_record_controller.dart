import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/side_mode_records.dart';
import 'game_controller.dart';

/// Kết quả 1 lần ghi nhận kỷ lục (cho UI ăn mừng "NEW BEST" / mở mốc).
class RecordOutcome {
  final SideModeKind kind;
  final bool newBest; // chỉ true cho metric best* khi vượt kỷ lục cũ
  final int newValue; // giá trị chỉ số sau khi cập nhật
  final RecordTier newTier; // bậc MỚI vừa mở (none nếu không mở mốc mới)
  final int milestoneCoins; // xu thưởng từ mốc mới (0 nếu không có)

  const RecordOutcome({
    required this.kind,
    required this.newBest,
    required this.newValue,
    required this.newTier,
    required this.milestoneCoins,
  });

  /// Có gì để ăn mừng (kỷ lục mới hoặc mốc mới)?
  bool get hasCelebration => newBest || newTier != RecordTier.none;
}

/// W19.1 — Theo dõi kỷ lục & cột mốc của từng chế độ phụ. Permanent controller
/// (như Achievement/Collection): RAM phải tự clear khi reset (xem
/// [[reset-permanent-controllers]]). KHÔNG đụng win-streak/level-unlock.
class SideModeRecordController extends GetxController {
  final GameController g;
  SideModeRecordController(this.g);

  final StorageService _store = StorageService.to;

  /// Giá trị chỉ số hiện tại của từng mode (best stage/score hoặc số lần thắng).
  final RxMap<SideModeKind, int> record = <SideModeKind, int>{}.obs;

  /// Bậc mốc ĐÃ NHẬN của từng mode (index RecordTier: 0=none..3=gold).
  final RxMap<SideModeKind, int> claimedTier = <SideModeKind, int>{}.obs;

  /// Số lần đã chơi từng mode (thống kê).
  final RxMap<SideModeKind, int> plays = <SideModeKind, int>{}.obs;

  /// Kết quả lần ghi nhận gần nhất (cho overlay đọc).
  RecordOutcome? lastOutcome;

  static SideModeRecordController? get maybe =>
      Get.isRegistered<SideModeRecordController>()
      ? Get.find<SideModeRecordController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _loadFromStore();
  }

  void _loadFromStore() {
    for (final spec in kSideModeRecords) {
      record[spec.kind] = _store.getInt(StorageKeys.recValue(spec.key));
      claimedTier[spec.kind] = _store.getInt(StorageKeys.recTier(spec.key));
      plays[spec.kind] = _store.getInt(StorageKeys.recPlays(spec.key));
    }
  }

  /// Xoá state in-memory khi reset tiến trình (disk xoá ở resetProgress).
  void resetState() {
    record.clear();
    claimedTier.clear();
    plays.clear();
    lastOutcome = null;
    for (final spec in kSideModeRecords) {
      record[spec.kind] = 0;
      claimedTier[spec.kind] = 0;
      plays[spec.kind] = 0;
    }
  }

  int recordOf(SideModeKind k) => record[k] ?? 0;
  int playsOf(SideModeKind k) => plays[k] ?? 0;
  RecordTier tierOf(SideModeKind k) =>
      RecordTier.values[(claimedTier[k] ?? 0).clamp(0, 3)];

  /// Chế độ phụ ĐANG chơi (null nếu không phải mode có kỷ lục: daily/versus/màn thường).
  SideModeKind? get activeKind {
    if (g.isEndless.value) return SideModeKind.endless;
    if (g.isBoss.value) return SideModeKind.boss;
    if (g.isRhythm.value) return SideModeKind.rhythm;
    if (g.isGravity.value) return SideModeKind.gravity;
    if (g.isSoda.value) return SideModeKind.soda;
    if (g.isColorRush.value) return SideModeKind.colorRush;
    if (g.isSurvival.value) return SideModeKind.survival;
    if (g.isLabyrinth.value) return SideModeKind.labyrinth;
    if (g.isRush.value) return SideModeKind.rush;
    return null;
  }

  /// Chỉ số 1 ván vừa kết thúc của [kind]. winCount: trả 1 nếu thắng (số gia tăng).
  int _runMetric(SideModeKind kind, bool won) {
    switch (kind) {
      case SideModeKind.endless:
        return g.endlessStage.value;
      case SideModeKind.survival:
        return g.score.value;
      case SideModeKind.boss:
        return won ? g.bossStage.value : 0; // chỉ tính khi HẠ được boss
      case SideModeKind.rush:
        return g.score.value; // bestScore — như Survival
      case SideModeKind.rhythm:
      case SideModeKind.gravity:
      case SideModeKind.colorRush:
      case SideModeKind.soda:
      case SideModeKind.labyrinth:
        return won ? 1 : 0; // số lần thắng cộng dồn
    }
  }

  /// Ghi nhận kết quả 1 ván side-mode. Trả [RecordOutcome] (null nếu mode không
  /// track — daily/versus). Cập nhật kỷ lục, mở mốc mới + thưởng xu (1 lần/mốc).
  RecordOutcome? recordResult({required bool won}) {
    final kind = activeKind;
    if (kind == null) return null;
    final spec = specForKind(kind);

    // playCount luôn tăng (kể cả thua).
    final newPlays = (plays[kind] ?? 0) + 1;
    plays[kind] = newPlays;
    unawaited(_store.setInt(StorageKeys.recPlays(spec.key), newPlays));

    final cur = record[kind] ?? 0;
    final run = _runMetric(kind, won);
    final int newVal;
    final bool newBest;
    if (spec.metric == RecordMetric.winCount) {
      newVal = cur + run; // run = 0/1
      newBest = false; // bộ đếm, không phải "phá kỷ lục"
    } else {
      newVal = run > cur ? run : cur;
      newBest = run > cur;
    }
    if (newVal != cur) {
      record[kind] = newVal;
      unawaited(_store.setInt(StorageKeys.recValue(spec.key), newVal));
    }

    // Mốc: nếu vượt bậc đã nhận → ghi cờ TRƯỚC khi cộng xu (anti-double).
    final reached = spec.tierFor(newVal);
    final claimed = claimedTier[kind] ?? 0;
    int coins = 0;
    var unlockedTier = RecordTier.none;
    if (reached.index > claimed) {
      claimedTier[kind] = reached.index;
      unawaited(_store.setInt(StorageKeys.recTier(spec.key), reached.index));
      for (int t = claimed + 1; t <= reached.index; t++) {
        coins += kTierReward[RecordTier.values[t]] ?? 0;
      }
      if (coins > 0) g.addCoins(coins);
      unlockedTier = reached;
    }

    final outcome = RecordOutcome(
      kind: kind,
      newBest: newBest,
      newValue: newVal,
      newTier: unlockedTier,
      milestoneCoins: coins,
    );
    lastOutcome = outcome;
    return outcome;
  }
}
