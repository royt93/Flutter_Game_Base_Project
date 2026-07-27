import '../logic/leaderboard.dart';

/// I38: danh sách bot ảo cố định cho tab Weekly Featured Level (tách khỏi
/// [kDailyChallengeLeaderboardBots]/[kGauntletLeaderboardBots] vì chơi lại 1
/// level campaign đã cân bằng — điểm cao hơn hẳn bàn daily-challenge nhỏ).
const List<LeaderboardEntry> kWeeklyFeaturedLeaderboardBots = [
  LeaderboardEntry('NovaStreak', 5000),
  LeaderboardEntry('PixelPop99', 4200),
  LeaderboardEntry('CandyKnight', 3400),
  LeaderboardEntry('StarChaser', 2700),
  LeaderboardEntry('BlazeRunner', 2000),
  LeaderboardEntry('GemHunter', 1400),
  LeaderboardEntry('LuckyPop', 900),
  LeaderboardEntry('ComboKid', 500),
  LeaderboardEntry('NeonRookie', 200),
  LeaderboardEntry('FreshStart', 50),
];
