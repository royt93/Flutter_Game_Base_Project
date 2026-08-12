/// I84: "Làm gì tiếp theo" — xếp hạng vài việc đáng làm nhất lúc này.
///
/// Vấn đề nó giải: game có 14 `GameMode` + ~20 hệ meta, còn Home chỉ **liệt
/// kê** chúng. Người chơi mở app và phải tự trả lời "hôm nay làm gì?" từ một
/// danh sách mà phần lớn đang ở trạng thái "chưa có gì để làm".
///
/// Thuần: không đọc `StorageService`, không `Get.find`, không đồng hồ — mọi
/// thứ vào qua tham số. Nhờ vậy test được toàn bộ bảng ưu tiên mà không cần
/// widget harness.
///
/// **Cố ý KHÔNG có trọng số/cấu hình.** Đây là chuỗi `if` theo thứ tự, đọc từ
/// trên xuống là ra luật. Muốn tinh chỉnh thì đổi thứ tự các nhánh — đó là
/// toàn bộ "tuning" cần thiết.
library;

enum NextActionKind {
  /// Sắp hết hạn trong ngày — mất là mất luôn.
  dailyReward,
  dailySpin,
  dailyQuest,
  raidBoss,

  /// Đã đủ điều kiện nhận nhưng chưa nhận — người chơi đang bỏ quên tiền.
  starRoadChest,
  seasonMilestone,
  weeklyGoal,
  clanGoal,

  /// Tiến độ chính.
  campaignLevel,
}

class NextAction {
  const NextAction(this.kind, {this.value});

  final NextActionKind kind;

  /// Số đi kèm để UI ghép vào chuỗi i18n (số màn kế tiếp, số quest xong…).
  /// `null` nếu mục đó không cần số.
  final int? value;

  @override
  bool operator ==(Object other) =>
      other is NextAction && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'NextAction($kind, $value)';
}

/// Số gợi ý tối đa hiện cùng lúc. Nhiều hơn là quay lại đúng vấn đề ban đầu —
/// một danh sách để người chơi tự lọc.
const int kMaxNextActions = 3;

/// Dưới mốc này coi là người chơi mới: **chỉ** gợi ý campaign + thưởng ngày.
/// Mọi hệ meta khác bị ẩn khỏi khu vực này cho tới khi họ đi đủ xa — carousel
/// đầy đủ vẫn nằm bên dưới cho ai muốn khám phá.
const int kNewPlayerLevelCap = 5;

/// Trả tối đa [kMaxNextActions] việc, đã xếp theo độ đáng làm.
///
/// Thứ tự ưu tiên:
/// 1. **Sắp hết hạn** và còn nhận được (thưởng ngày, vòng quay, quest gần
///    xong, raid ngày cuối) — bỏ lỡ là mất hẳn.
/// 2. **Đã đủ điều kiện mà chưa nhận** (rương, mốc mùa, mục tiêu tuần, pool
///    clan) — tiền đang nằm đó.
/// 3. Tiến độ campaign.
///
/// Mọi cờ vào đây phải đã tính sẵn "còn nhận được không" ở phía caller; hàm
/// này không tự suy ra điều kiện mở khoá.
List<NextAction> rankNextActions({
  required bool canClaimDailyReward,
  required bool canClaimSpin,
  required int questsReadyToClaim,
  required bool weeklyGoalReady,
  required bool clanGoalReady,
  required bool chestReady,
  required bool seasonMilestoneReady,
  required bool raidActiveToday,
  required bool raidHasAttemptsLeft,
  required int unlockedLevel,
  required int levelCount,
}) {
  final out = <NextAction>[];

  void add(NextActionKind kind, [int? value]) {
    if (out.length < kMaxNextActions) out.add(NextAction(kind, value: value));
  }

  final isNewPlayer = unlockedLevel <= kNewPlayerLevelCap;

  // Nhóm 1 — hết hạn theo ngày.
  if (canClaimDailyReward) add(NextActionKind.dailyReward);

  if (!isNewPlayer) {
    if (canClaimSpin) add(NextActionKind.dailySpin);
    if (questsReadyToClaim > 0) {
      add(NextActionKind.dailyQuest, questsReadyToClaim);
    }
    if (raidActiveToday && raidHasAttemptsLeft) add(NextActionKind.raidBoss);

    // Nhóm 2 — đã đủ điều kiện, chưa nhận.
    if (chestReady) add(NextActionKind.starRoadChest);
    if (seasonMilestoneReady) add(NextActionKind.seasonMilestone);
    if (weeklyGoalReady) add(NextActionKind.weeklyGoal);
    if (clanGoalReady) add(NextActionKind.clanGoal);
  }

  // Nhóm 3 — tiến độ chính. Luôn là phương án cuối, và chỉ khi còn màn để
  // chơi (đã phá đảo thì không gợi ý "màn kế tiếp" nữa).
  if (unlockedLevel <= levelCount) {
    add(NextActionKind.campaignLevel, unlockedLevel);
  }

  return out;
}
