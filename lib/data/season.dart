import 'package:flutter/foundation.dart';
import 'battle_pass.dart' show RewardKind;

/// Sự kiện theo mùa (Wave 7) — mỗi mùa = 1 TUẦN, dựa hoàn toàn vào đồng hồ
/// thiết bị (offline, không backend). Mỗi mùa có theme + tên riêng, người chơi
/// tích "điểm mùa" khi thắng để mở các mốc thưởng.

/// Số ngày 1 mùa.
const int kSeasonDays = 7;

/// Chỉ số mùa tuyệt đối từ epoch-day (mỗi 7 ngày +1).
int seasonIndex(int epochDay) => epochDay ~/ kSeasonDays;

/// epoch-day bắt đầu / kết thúc (loại trừ) của mùa chứa [epochDay].
int seasonStartDay(int epochDay) => seasonIndex(epochDay) * kSeasonDays;
int seasonEndDay(int epochDay) => seasonStartDay(epochDay) + kSeasonDays;

/// 5 theme mùa xoay vòng (key i18n tên).
const List<String> kSeasonNameKeys = [
  'season_cyan',
  'season_magenta',
  'season_lime',
  'season_amber',
  'season_violet',
];

String seasonNameKey(int idx) => kSeasonNameKeys[idx % kSeasonNameKeys.length];

/// World accent dùng cho theme mùa (1-indexed → +1).
int seasonWorldAccent(int idx) => (idx % 5) + 1;

@immutable
class SeasonMilestone {
  final int points; // điểm tích luỹ để mở
  final RewardKind kind;
  final int amount;
  const SeasonMilestone(this.points, this.kind, this.amount);
}

/// 6 mốc thưởng mùa (điểm tích luỹ tăng dần).
const List<SeasonMilestone> kSeasonMilestones = [
  SeasonMilestone(50, RewardKind.coins, 60),
  SeasonMilestone(120, RewardKind.coins, 50), // (gộp: 5 shard → 50 xu)
  SeasonMilestone(220, RewardKind.hammer, 1),
  SeasonMilestone(350, RewardKind.coins, 130),
  SeasonMilestone(520, RewardKind.coins, 90), // (gộp: 9 shard → 90 xu)
  SeasonMilestone(720, RewardKind.moves, 2),
];

/// Điểm mùa nhận khi thắng 1 màn: nền 10 + 8 mỗi sao.
int seasonPointsForWin(int stars) => 10 + stars * 8;

/// W28.5 — sự kiện tuần toàn app, hiển thị banner World Map. Dùng chung
/// [seasonIndex] nên cùng ranh giới tuần với Season League (không cần
/// epoch-week/anti-cheat riêng — thừa hưởng bảo vệ chống lùi giờ từ
/// [seasonIndex] vì đầu vào luôn là `todayEpochDay` đã bảo vệ).
@immutable
class WeeklyEvent {
  final String nameKey;
  final String descKey;
  final double coinMult;
  const WeeklyEvent(this.nameKey, this.descKey, this.coinMult);
}

/// 4 sự kiện xoay vòng — hệ số trong khoảng 1.0-1.5 (không phá cân bằng kinh
/// tế). Chỉ buff coin thưởng cuối màn, KHÔNG đụng công thức tính điểm/sao.
const List<WeeklyEvent> kWeeklyEvents = [
  WeeklyEvent('event_none_name', 'event_none_desc', 1.0),
  WeeklyEvent('event_coin_name', 'event_coin_desc', 1.3),
  WeeklyEvent('event_combo_name', 'event_combo_desc', 1.2),
  WeeklyEvent('event_bigcoin_name', 'event_bigcoin_desc', 1.5),
];

WeeklyEvent currentWeeklyEvent(int epochDay) =>
    kWeeklyEvents[seasonIndex(epochDay) % kWeeklyEvents.length];
