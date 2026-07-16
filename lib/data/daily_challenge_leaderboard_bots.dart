import '../logic/leaderboard.dart';

/// F13/I9 — danh sách bot ảo cố định cho tab Daily Challenge (tách khỏi
/// [kLeaderboardBots] vì thang điểm khác hẳn: 1 lần chơi/ngày trên bàn
/// `dailyChallengeRows x dailyChallengeCols`, không phải tổng sao campaign).
const List<LeaderboardEntry> kDailyChallengeLeaderboardBots = [
  LeaderboardEntry('NovaStreak', 3000),
  LeaderboardEntry('PixelPop99', 2500),
  LeaderboardEntry('CandyKnight', 2000),
  LeaderboardEntry('StarChaser', 1600),
  LeaderboardEntry('BlazeRunner', 1200),
  LeaderboardEntry('GemHunter', 900),
  LeaderboardEntry('LuckyPop', 650),
  LeaderboardEntry('ComboKid', 400),
  LeaderboardEntry('NeonRookie', 200),
  LeaderboardEntry('FreshStart', 50),
];
