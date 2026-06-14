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
  SeasonMilestone(120, RewardKind.shards, 5),
  SeasonMilestone(220, RewardKind.hammer, 1),
  SeasonMilestone(350, RewardKind.coins, 130),
  SeasonMilestone(520, RewardKind.shards, 9),
  SeasonMilestone(720, RewardKind.moves, 2),
];

/// Điểm mùa nhận khi thắng 1 màn: nền 10 + 8 mỗi sao.
int seasonPointsForWin(int stars) => 10 + stars * 8;
