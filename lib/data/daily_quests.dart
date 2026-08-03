import 'dart:math';

enum QuestKind { popGems, winAnyMode, threeStarLevel }

class DailyQuest {
  const DailyQuest({
    required this.kind,
    required this.target,
    required this.coinReward,
    required this.nameKey,
  });

  final QuestKind kind;
  final int target;
  final int coinReward;
  final String nameKey;
}

const List<DailyQuest> kDailyQuestPool = [
  DailyQuest(
    kind: QuestKind.popGems,
    target: 30,
    coinReward: 20,
    nameKey: 'daily_quest_pop_30',
  ),
  DailyQuest(
    kind: QuestKind.popGems,
    target: 60,
    coinReward: 35,
    nameKey: 'daily_quest_pop_60',
  ),
  DailyQuest(
    kind: QuestKind.popGems,
    target: 100,
    coinReward: 55,
    nameKey: 'daily_quest_pop_100',
  ),
  DailyQuest(
    kind: QuestKind.winAnyMode,
    target: 1,
    coinReward: 25,
    nameKey: 'daily_quest_win_1',
  ),
  DailyQuest(
    kind: QuestKind.winAnyMode,
    target: 2,
    coinReward: 45,
    nameKey: 'daily_quest_win_2',
  ),
  DailyQuest(
    kind: QuestKind.winAnyMode,
    target: 3,
    coinReward: 65,
    nameKey: 'daily_quest_win_3',
  ),
  DailyQuest(
    kind: QuestKind.threeStarLevel,
    target: 1,
    coinReward: 40,
    nameKey: 'daily_quest_three_star_1',
  ),
  DailyQuest(
    kind: QuestKind.threeStarLevel,
    target: 2,
    coinReward: 70,
    nameKey: 'daily_quest_three_star_2',
  ),
];

/// Deterministically selects three distinct pool entries for [epochDay].
List<DailyQuest> questsForDay(int epochDay) {
  final indices = List<int>.generate(kDailyQuestPool.length, (i) => i);
  indices.shuffle(Random(epochDay));
  return indices.take(3).map((i) => kDailyQuestPool[i]).toList(growable: false);
}
