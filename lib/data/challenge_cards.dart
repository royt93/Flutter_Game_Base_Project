import 'dart:math';

import 'side_mode_records.dart';

/// Wave 20.3 — Challenge Card: 3 thử thách tất định mỗi tuần.
/// W25.3 — thêm `reachRecordTier` (quest kỹ năng, xoay tuần lẻ).
enum ChallengeType { winCampaign, earnCoins, playMode, reachRecordTier }

class ChallengeCard {
  final ChallengeType type;
  final int target;
  final int reward; // xu
  final String modeKey; // chỉ dùng khi type=playMode
  final SideModeKind? recordKind; // chỉ dùng khi type=reachRecordTier
  final RecordTier? recordTier; // chỉ dùng khi type=reachRecordTier
  const ChallengeCard({
    required this.type,
    required this.target,
    required this.reward,
    this.modeKey = '',
    this.recordKind,
    this.recordTier,
  });
}

/// W25.3 — trục điểm side-mode/tuần (tách biệt campaign, KHÔNG đụng win-streak/
/// unlock/lives). Thắng 1 ván side-mode bất kỳ +[kSideWeeklyPointsPerWin],
/// +bonus nếu vừa mở mốc kỷ lục mới (bronze/silver/gold/platinum).
const int kSideWeeklyPointsPerWin = 12;
const int kSideWeeklyPointsPerMilestoneUnlock = 25;
const List<int> kSideWeeklyGoals = [80, 200, 400];
const List<int> kSideWeeklyRewards = [60, 120, 220];

/// W25.3 — bonus XP nhỏ cho Battle Pass khi nhận mốc điểm side-mode/tuần
/// (không đụng gate campaign-only của `recordLevelEnd`).
const int kSideMilestoneBpBonusXp = 15;

/// Tạo 3 thử thách cho [weekIdx] (tất định — cùng tuần = cùng set).
List<ChallengeCard> buildWeeklyChallenges(int weekIdx) {
  final rnd = Random(weekIdx ^ 0x57A3C9);
  final cards = <ChallengeCard>[];

  // Luôn có 1 winCampaign
  cards.add(
    ChallengeCard(
      type: ChallengeType.winCampaign,
      target: 3 + rnd.nextInt(5), // 3-7 màn
      reward: 150,
    ),
  );

  // 1 earnCoins
  final coinTarget = (3 + rnd.nextInt(5)) * 100; // 300-700 xu
  cards.add(
    ChallengeCard(
      type: ChallengeType.earnCoins,
      target: coinTarget,
      reward: 200,
    ),
  );

  // Thẻ thứ 3: tuần chẵn = playMode (như cũ), tuần lẻ = quest kỹ năng
  // reachRecordTier (W25.3 — không đổi hành vi tuần chẵn đã có).
  if (weekIdx.isEven) {
    const modes = [
      'endless_short',
      'boss_short',
      'rhythm_short',
      'gravity_short',
      'soda_short',
      'color_rush_short',
      'rush_short',
    ];
    final modeKey = modes[rnd.nextInt(modes.length)];
    cards.add(
      ChallengeCard(
        type: ChallengeType.playMode,
        target: 2 + rnd.nextInt(3), // 2-4 lần
        reward: 150,
        modeKey: modeKey,
      ),
    );
  } else {
    final spec = kSideModeRecords[rnd.nextInt(kSideModeRecords.length)];
    cards.add(
      ChallengeCard(
        type: ChallengeType.reachRecordTier,
        target: 1,
        reward: 220, // khó hơn playMode (dựa lifetime record) → thưởng cao hơn
        recordKind: spec.kind,
        recordTier: RecordTier.bronze,
      ),
    );
  }

  return cards;
}
