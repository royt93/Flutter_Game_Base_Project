import '../logic/leaderboard.dart';

/// I33: danh sách bot ảo cố định cho tab Gauntlet — tách khỏi
/// [kDailyChallengeLeaderboardBots] vì modifier hôm nay có thể hạ trần điểm
/// (vd 4 màu, combo timer ngắn) nên thang điểm không khớp Daily Challenge.
const List<LeaderboardEntry> kGauntletLeaderboardBots = [
  LeaderboardEntry('ModShifter', 2600),
  LeaderboardEntry('RuleBreaker', 2200),
  LeaderboardEntry('ChaosAce', 1800),
  LeaderboardEntry('TwistMaster', 1400),
  LeaderboardEntry('OddOneOut', 1000),
  LeaderboardEntry('WildCarder', 750),
  LeaderboardEntry('WarpRunner', 500),
  LeaderboardEntry('WobblePop', 300),
  LeaderboardEntry('NeonNewbie', 150),
  LeaderboardEntry('FreshStart', 40),
];
