import 'package:flutter/foundation.dart';

/// Loại nhiệm vụ ngày — chỉ dùng dữ liệu có sẵn lúc KẾT THÚC màn (không cần
/// chạm engine Flame): thắng, chơi, kiếm xu, combo cao nhất ván, sao đạt.
enum QuestType { winLevels, playLevels, earnCoins, reachCombo, collectStars }

/// Phần thưởng (dùng chung cho mốc pass).
enum RewardKind { coins, shards, hammer, moves }

@immutable
class QuestTemplate {
  final QuestType type;
  final int target; // ngưỡng hoàn thành
  final int xp; // XP pass khi xong
  const QuestTemplate(this.type, this.target, this.xp);

  /// Key i18n mô tả (target nhúng qua @n ở UI).
  String get descKey {
    switch (type) {
      case QuestType.winLevels:
        return 'quest_win';
      case QuestType.playLevels:
        return 'quest_play';
      case QuestType.earnCoins:
        return 'quest_coins';
      case QuestType.reachCombo:
        return 'quest_combo';
      case QuestType.collectStars:
        return 'quest_stars';
    }
  }
}

/// Kho mẫu nhiệm vụ — chọn 3 cái/ngày theo seed = epoch-day (xác định, test được).
const List<QuestTemplate> kQuestPool = [
  QuestTemplate(QuestType.winLevels, 3, 40),
  QuestTemplate(QuestType.winLevels, 5, 70),
  QuestTemplate(QuestType.playLevels, 5, 30),
  QuestTemplate(QuestType.earnCoins, 120, 40),
  QuestTemplate(QuestType.earnCoins, 250, 70),
  QuestTemplate(QuestType.reachCombo, 5, 40),
  QuestTemplate(QuestType.reachCombo, 7, 70),
  QuestTemplate(QuestType.collectStars, 6, 50),
  QuestTemplate(QuestType.collectStars, 10, 90),
];

/// 3 nhiệm vụ của ngày [epochDay] — xác định theo seed, không trùng type.
List<QuestTemplate> dailyQuests(int epochDay) {
  final out = <QuestTemplate>[];
  final usedTypes = <QuestType>{};
  // duyệt kho theo offset xoay vòng tránh trùng loại
  for (int i = 0; out.length < 3 && i < kQuestPool.length * 2; i++) {
    final q = kQuestPool[(epochDay + i * 3) % kQuestPool.length];
    if (usedTypes.add(q.type)) out.add(q);
  }
  // phòng hờ thiếu → bù từ đầu kho
  for (int i = 0; out.length < 3; i++) {
    out.add(kQuestPool[(epochDay + i) % kQuestPool.length]);
  }
  return out.take(3).toList();
}

@immutable
class PassTier {
  final int xpNeeded; // XP TÍCH LUỸ để đạt cấp này
  final RewardKind kind;
  final int amount;
  const PassTier(this.xpNeeded, this.kind, this.amount);
}

/// Track Battle Pass — 12 cấp, XP tích luỹ tăng dần, thưởng xen kẽ.
const List<PassTier> kPassTiers = [
  PassTier(60, RewardKind.coins, 50),
  PassTier(140, RewardKind.shards, 4),
  PassTier(240, RewardKind.hammer, 1),
  PassTier(360, RewardKind.coins, 90),
  PassTier(500, RewardKind.moves, 1),
  PassTier(660, RewardKind.shards, 6),
  PassTier(840, RewardKind.coins, 140),
  PassTier(1040, RewardKind.hammer, 2),
  PassTier(1260, RewardKind.shards, 9),
  PassTier(1500, RewardKind.coins, 220),
  PassTier(1760, RewardKind.moves, 2),
  PassTier(2040, RewardKind.shards, 14),
];
