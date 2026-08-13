import 'worlds.dart';

/// F14: perk vĩnh viễn, mở khoá khi hoàn thành 1 world — KHÔNG mua bằng
/// coin/tiền thật. Hiệu ứng tiện ích nhẹ, không đổi target/luật thắng-thua.
enum PerkEffect {
  extraUndo,
  moveHint,
  coinBonus,

  // I83 — perk prestige, mở bằng constellation (xem `constellations.dart`).
  // Toàn bộ đều là kinh tế/tiện ích, KHÔNG chạm điểm số.
  /// Giá mọi booster trong shop rẻ hơn.
  boosterDiscount,

  /// Thêm Star Dust mỗi lần thắng 3 sao.
  starDustBonus,

  /// Craft point nhận được nhân thêm.
  craftBonus,

  /// Lần "cơ hội thứ hai" ([[I88]]) đầu tiên mỗi màn miễn phí.
  freeSecondChance,
}

class Perk {
  final String id;
  final String nameKey;
  final String descKey;
  final PerkEffect effect;
  final int unlockAfterWorld; // hoàn thành world thứ N (1-based) thì mở khoá

  const Perk({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.effect,
    required this.unlockAfterWorld,
  });
}

const List<Perk> kPerks = [
  Perk(
    id: 'extra_undo',
    nameKey: 'perk_extra_undo',
    descKey: 'perk_extra_undo_desc',
    effect: PerkEffect.extraUndo,
    unlockAfterWorld: 1,
  ),
  Perk(
    id: 'move_hint',
    nameKey: 'perk_move_hint',
    descKey: 'perk_move_hint_desc',
    effect: PerkEffect.moveHint,
    unlockAfterWorld: 2,
  ),
  Perk(
    id: 'coin_bonus',
    nameKey: 'perk_coin_bonus',
    descKey: 'perk_coin_bonus_desc',
    effect: PerkEffect.coinBonus,
    unlockAfterWorld: 3,
  ),
];

/// Số world đã hoàn thành (đã unlock qua hết level cuối world đó), suy từ
/// [unlockedLevel] — thuần, test được không cần GameController.
int worldsCompleted(int unlockedLevel) =>
    kWorlds.where((w) => unlockedLevel > w.endId).length;

/// Perk đã mở khoá theo tiến độ world hiện tại.
List<Perk> unlockedPerks(int unlockedLevel) {
  final done = worldsCompleted(unlockedLevel);
  return kPerks.where((p) => p.unlockAfterWorld <= done).toList();
}
