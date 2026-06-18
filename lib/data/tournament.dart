import 'package:flutter/foundation.dart';
import 'battle_pass.dart' show RewardKind;

/// Giải đấu theo TUẦN (Wave 14) — offline thuần, không backend. Người chơi tích
/// "điểm giải" khi thắng; bảng xếp hạng gồm người chơi + 7 bot AI có điểm SINH
/// TẤT ĐỊNH theo tuần (seed = tuần) leo dần theo ngày → tạo cảm giác đua hạng.
/// Cuối tuần (hoặc bất cứ lúc nào) nhận thưởng theo HẠNG, 1 lần/tuần.

/// Số ngày 1 giải (1 tuần).
const int kTournamentDays = 7;

/// Chỉ số tuần tuyệt đối từ epoch-day.
int tournamentWeek(int epochDay) => epochDay ~/ kTournamentDays;

/// epoch-day bắt đầu / kết thúc (loại trừ) của tuần chứa [epochDay].
int tournamentWeekStart(int epochDay) => tournamentWeek(epochDay) * kTournamentDays;
int tournamentWeekEnd(int epochDay) => tournamentWeekStart(epochDay) + kTournamentDays;

/// Điểm giải nhận khi thắng 1 màn: nền 12 + 6 mỗi sao.
int tournamentPointsForWin(int stars) => 12 + stars * 6;

@immutable
class TournamentBot {
  final String name; // tên hiển thị (proper noun — không dịch)
  final int base; // điểm khởi đầu đầu tuần
  final int growth; // điểm tăng mỗi ngày (xấp xỉ)
  const TournamentBot(this.name, this.base, this.growth);
}

/// 7 đối thủ bot — định danh cố định; điểm thực tế biến thiên theo tuần (seed).
const List<TournamentBot> kTournamentBots = [
  TournamentBot('Nova', 60, 70),
  TournamentBot('Zyra', 90, 60),
  TournamentBot('Echo', 40, 80),
  TournamentBot('Lumen', 120, 50),
  TournamentBot('Pyx', 30, 90),
  TournamentBot('Vortex', 150, 45),
  TournamentBot('Glint', 75, 65),
];

/// Điểm của bot [botIndex] tại [dayIntoWeek] (0..6) trong tuần [week] — TẤT ĐỊNH
/// (không Random runtime): trộn seed tuần để mỗi tuần thứ hạng bot khác nhau.
int botScore(int week, int botIndex, int dayIntoWeek) {
  final b = kTournamentBots[botIndex];
  // jitter tất định theo (tuần, bot): ±40% growth, không dùng Random.
  final mix = (week * 2654435761 + botIndex * 40503) & 0x7fffffff;
  final jitterBase = (mix % 61) - 30; // -30..30
  final jitterGrowth = ((mix >> 8) % 41) - 20; // -20..20
  final g = (b.growth + jitterGrowth).clamp(20, 200);
  final d = dayIntoWeek.clamp(0, kTournamentDays - 1);
  return (b.base + jitterBase).clamp(0, 1 << 30) + g * d;
}

@immutable
class TournamentReward {
  final RewardKind kind;
  final int amount;
  const TournamentReward(this.kind, this.amount);
}

/// Thưởng theo HẠNG cuối (1-based). Index 0 = hạng 1. Có 8 hạng (1 người + 7 bot).
const List<TournamentReward> kTournamentRewards = [
  TournamentReward(RewardKind.coins, 300), // hạng 1
  TournamentReward(RewardKind.coins, 200), // hạng 2
  TournamentReward(RewardKind.coins, 140), // hạng 3
  TournamentReward(RewardKind.coins, 100), // hạng 4
  TournamentReward(RewardKind.coins, 70), // hạng 5
  TournamentReward(RewardKind.coins, 50), // hạng 6
  TournamentReward(RewardKind.coins, 35), // hạng 7
  TournamentReward(RewardKind.coins, 20), // hạng 8 (chót)
];

/// Thưởng cho [rank] (1-based, clamp về dải hợp lệ).
TournamentReward tournamentRewardFor(int rank) =>
    kTournamentRewards[(rank - 1).clamp(0, kTournamentRewards.length - 1)];
