/// W19.1 — Kỷ lục & cột mốc (milestone) cho từng CHẾ ĐỘ PHỤ.
///
/// Mỗi chế độ phụ track 1 chỉ số (metric) chỉ-tăng + 3 mốc Bronze/Silver/Gold.
/// Đạt mốc → badge trên Home + thưởng nhỏ xu (nhận 1 lần, anti-exploit). KHÔNG
/// đụng kinh tế Campaign. Thuần data (không phụ thuộc Flame/GetX) → test được.
///
/// Daily (đã có streak riêng) và Versus (PvP) KHÔNG nằm trong hệ này.
library;

/// Chế độ phụ có theo dõi kỷ lục.
enum SideModeKind {
  endless,
  boss,
  rhythm,
  gravity,
  soda,
  colorRush,
  survival,
  labyrinth,
  rush,
}

/// Loại chỉ số được track:
/// - bestStage: stage cao nhất đạt được (Endless / Boss) — chỉ tăng.
/// - bestScore: điểm cao nhất 1 ván (Survival) — chỉ tăng.
/// - winCount: tổng số lần THẮNG tích luỹ (các mode có "win" cố định mục tiêu).
enum RecordMetric { bestStage, bestScore, winCount }

/// Bậc cột mốc. Thứ tự index DÙNG để so sánh tiến triển
/// (none<bronze<silver<gold<platinum). W25.3: thêm platinum ở CUỐI — giữ
/// nguyên index 3 cũ của gold để không phá dữ liệu đã lưu.
enum RecordTier { none, bronze, silver, gold, platinum }

/// Thưởng xu khi đạt mốc (nhỏ — giữ vai cosmetic chính cho Album/Shop).
const Map<RecordTier, int> kTierReward = {
  RecordTier.bronze: 30,
  RecordTier.silver: 60,
  RecordTier.gold: 120,
  RecordTier.platinum: 220,
};

/// Đặc tả 1 chế độ phụ: chỉ số + 4 ngưỡng mốc.
class SideModeRecordSpec {
  final SideModeKind kind;
  final String key; // prefix lưu trữ ('endless', 'boss', …)
  final RecordMetric metric;
  final int bronze;
  final int silver;
  final int gold;
  final int platinum;

  const SideModeRecordSpec({
    required this.kind,
    required this.key,
    required this.metric,
    required this.bronze,
    required this.silver,
    required this.gold,
    required this.platinum,
  });

  /// Bậc mốc đạt được với [value] (none nếu chưa tới bronze).
  RecordTier tierFor(int value) {
    if (value >= platinum) return RecordTier.platinum;
    if (value >= gold) return RecordTier.gold;
    if (value >= silver) return RecordTier.silver;
    if (value >= bronze) return RecordTier.bronze;
    return RecordTier.none;
  }

  /// Ngưỡng của 1 bậc (0 cho none).
  int thresholdFor(RecordTier t) {
    switch (t) {
      case RecordTier.none:
        return 0;
      case RecordTier.bronze:
        return bronze;
      case RecordTier.silver:
        return silver;
      case RecordTier.gold:
        return gold;
      case RecordTier.platinum:
        return platinum;
    }
  }
}

/// Key i18n tên ngắn hiển thị theo mode (dùng cho quest kỹ năng W25.3) — tái
/// dùng nguyên vẹn các key `_short` đã dịch đủ 22 ngôn ngữ, không dịch lại.
String shortKeyFor(SideModeKind k) {
  switch (k) {
    case SideModeKind.endless:
      return 'endless_short';
    case SideModeKind.boss:
      return 'boss_short';
    case SideModeKind.rhythm:
      return 'rhythm_short';
    case SideModeKind.gravity:
      return 'gravity_short';
    case SideModeKind.soda:
      return 'soda_short';
    case SideModeKind.colorRush:
      return 'color_rush_short';
    case SideModeKind.survival:
      return 'survival_short';
    case SideModeKind.labyrinth:
      return 'labyrinth_short';
    case SideModeKind.rush:
      return 'rush_short';
  }
}

/// Bảng đặc tả cho 8 chế độ phụ. Ngưỡng chọn theo mục tiêu thực của mode:
/// - Endless/Boss: stage (không trần) → đo độ "đi xa".
/// - Survival: điểm (không trần, không có "win") → đo độ "sống dai".
/// - 5 mode còn lại: WIN COUNT (mục tiêu cố định → điểm/chai bị trần khi thắng,
///   nên đếm số lần thắng mới là chỉ số tăng có ý nghĩa).
const List<SideModeRecordSpec> kSideModeRecords = [
  SideModeRecordSpec(
    kind: SideModeKind.endless,
    key: 'endless',
    metric: RecordMetric.bestStage,
    bronze: 5,
    silver: 15,
    gold: 30,
    platinum: 60,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.boss,
    key: 'boss',
    metric: RecordMetric.bestStage,
    bronze: 1,
    silver: 3,
    gold: 5,
    platinum: 8,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.survival,
    key: 'survival',
    metric: RecordMetric.bestScore,
    bronze: 2000,
    silver: 5000,
    gold: 10000,
    platinum: 20000,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.rhythm,
    key: 'rhythm',
    metric: RecordMetric.winCount,
    bronze: 1,
    silver: 5,
    gold: 15,
    platinum: 30,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.gravity,
    key: 'gravity',
    metric: RecordMetric.winCount,
    bronze: 1,
    silver: 5,
    gold: 15,
    platinum: 30,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.colorRush,
    key: 'colorRush',
    metric: RecordMetric.winCount,
    bronze: 1,
    silver: 5,
    gold: 15,
    platinum: 30,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.soda,
    key: 'soda',
    metric: RecordMetric.winCount,
    bronze: 1,
    silver: 5,
    gold: 15,
    platinum: 30,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.labyrinth,
    key: 'labyrinth',
    metric: RecordMetric.winCount,
    bronze: 1,
    silver: 5,
    gold: 15,
    platinum: 30,
  ),
  SideModeRecordSpec(
    kind: SideModeKind.rush,
    key: 'rush',
    metric: RecordMetric.bestScore,
    bronze: 5000,
    silver: 20000,
    gold: 60000,
    platinum: 120000,
  ),
];

/// Đặc tả của 1 chế độ (ném [StateError] nếu không có — luôn có cho mọi enum).
SideModeRecordSpec specForKind(SideModeKind k) =>
    kSideModeRecords.firstWhere((s) => s.kind == k);
