import '../logic/leaderboard.dart';

/// I9 — danh sách bot ảo cố định (không phải người chơi thật, không đồng bộ
/// mạng). Mốc sao tăng dần, trải đều tới ~600 (200 màn * 3 sao tối đa).
const List<LeaderboardEntry> kLeaderboardBots = [
  LeaderboardEntry('NovaStreak', 580),
  LeaderboardEntry('PixelPop99', 520),
  LeaderboardEntry('CandyKnight', 460),
  LeaderboardEntry('StarChaser', 400),
  LeaderboardEntry('BlazeRunner', 340),
  LeaderboardEntry('GemHunter', 280),
  LeaderboardEntry('LuckyPop', 220),
  LeaderboardEntry('ComboKid', 160),
  LeaderboardEntry('NeonRookie', 100),
  LeaderboardEntry('FreshStart', 40),
];
