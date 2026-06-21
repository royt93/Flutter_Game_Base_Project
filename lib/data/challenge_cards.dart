import 'dart:math';

/// Wave 20.3 — Challenge Card: 3 thử thách tất định mỗi tuần.
enum ChallengeType { winCampaign, earnCoins, playMode }

class ChallengeCard {
  final ChallengeType type;
  final int target;
  final int reward; // xu
  final String modeKey; // chỉ dùng khi type=playMode
  const ChallengeCard({
    required this.type,
    required this.target,
    required this.reward,
    this.modeKey = '',
  });
}

/// Tạo 3 thử thách cho [weekIdx] (tất định — cùng tuần = cùng set).
List<ChallengeCard> buildWeeklyChallenges(int weekIdx) {
  final rnd = Random(weekIdx ^ 0x57A3C9);
  final cards = <ChallengeCard>[];

  // Luôn có 1 winCampaign
  cards.add(ChallengeCard(
    type: ChallengeType.winCampaign,
    target: 3 + rnd.nextInt(5), // 3-7 màn
    reward: 150,
  ));

  // 1 earnCoins
  final coinTarget = (3 + rnd.nextInt(5)) * 100; // 300-700 xu
  cards.add(ChallengeCard(
    type: ChallengeType.earnCoins,
    target: coinTarget,
    reward: 200,
  ));

  // 1 playMode (xoay vòng chế độ phụ)
  const modes = [
    'endless_short', 'boss_short', 'rhythm_short',
    'gravity_short', 'soda_short', 'color_rush_short',
  ];
  final modeKey = modes[rnd.nextInt(modes.length)];
  cards.add(ChallengeCard(
    type: ChallengeType.playMode,
    target: 2 + rnd.nextInt(3), // 2-4 lần
    reward: 150,
    modeKey: modeKey,
  ));

  return cards;
}
