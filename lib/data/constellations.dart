import 'package:flutter/material.dart';

import '../core/neon_theme.dart';
import 'perks.dart';

/// Spec cho 1 chòm sao trên Con đường Sao (Sky Shrine).
class Constellation {
  const Constellation({
    required this.id,
    required this.nameKey,
    required this.starsRequired,
    required this.auraVariant,
    required this.color,
    required this.icon,
  });

  final String id;
  final String nameKey;
  final int starsRequired;
  final String auraVariant;
  final Color color;
  final IconData icon;
}

/// Danh sách chòm sao cố định với mốc sao tăng dần.
const List<Constellation> kConstellations = [
  Constellation(
    id: 'starlight_phoenix',
    nameKey: 'constellation_phoenix',
    starsRequired: 20,
    auraVariant: 'starlight',
    color: NeonTheme.gold,
    icon: Icons.auto_awesome_rounded,
  ),
  Constellation(
    id: 'cyan_dragon',
    nameKey: 'constellation_dragon',
    starsRequired: 60,
    auraVariant: 'cyan_blaze',
    color: NeonTheme.cyan,
    icon: Icons.shield_rounded,
  ),
  Constellation(
    id: 'nebula_pegasus',
    nameKey: 'constellation_pegasus',
    starsRequired: 120,
    auraVariant: 'nebula_pulse',
    color: NeonTheme.magenta,
    icon: Icons.workspace_premium_rounded,
  ),
  Constellation(
    id: 'cosmic_serpent',
    nameKey: 'constellation_serpent',
    starsRequired: 200,
    auraVariant: 'cosmic_drift',
    color: NeonTheme.purple,
    icon: Icons.all_inclusive_rounded,
  ),
];

/// Pure predicate: chòm sao [c] đã được thắp sáng khi [totalStars] >= [c.starsRequired].
bool isConstellationLit(Constellation c, int totalStars) =>
    totalStars >= c.starsRequired;

/// I83 — Sky Shrine thành cây kỹ năng cho New Game+.
///
/// ## Vì sao KHÔNG dựng hệ buff thứ ba
///
/// Task gốc đề xuất một skill tree riêng. Phác thảo xong thì lộ ra vấn đề mà
/// chính task đã lường: `PerkEffect` (F14) là `extraUndo/moveHint/coinBonus`,
/// còn `PetPassive` ([[I82]]) là `extraUndo/extraHint/coinBonus` — **trùng
/// nhau**. Thêm hệ thứ ba nói cùng ba điều đó là nhiễu thuần tuý, và người
/// chơi phải tự cộng ba nguồn buff trong đầu.
///
/// Nên đi đúng đường rẻ ghi trong mục "Ghi chú" của task: constellation **mở
/// thêm perk vào chính hệ F14**, không dựng cây riêng. Tái dùng nguyên
/// `activePerkIds`, `togglePerk`, `PerksScreen` — không có đường buff thứ ba.
///
/// ## Vì sao 4 hiệu ứng này
///
/// Tất cả đều thuộc **kinh tế/tiện ích, không chạm điểm số**. Đó là ràng buộc
/// cứng: bàn campaign không refill nên `targetScore` rất nhạy (xem "Target
/// achievability" trong CLAUDE.md), và AC của task lo cả hai chiều — màn bất
/// khả thi lẫn màn dễ tới mức 3 sao tự động. Hiệu ứng không đổi điểm thì
/// `levels_achievability_test` giữ nguyên kết quả ở mọi tier, không cần
/// mô phỏng lại.
///
/// Mỗi perk khoá sau **một** constellation cụ thể, và **chỉ có hiệu lực từ
/// prestige tier ≥ 1** — ở tier 0 chúng hiện dạng xem trước để tạo động lực
/// prestige.
const List<Perk> kPrestigePerks = [
  Perk(
    id: 'pp_discount',
    nameKey: 'pp_discount',
    descKey: 'pp_discount_desc',
    effect: PerkEffect.boosterDiscount,
    unlockAfterWorld: 0, // không dùng: gating theo constellation, xem dưới
  ),
  Perk(
    id: 'pp_star_dust',
    nameKey: 'pp_star_dust',
    descKey: 'pp_star_dust_desc',
    effect: PerkEffect.starDustBonus,
    unlockAfterWorld: 0,
  ),
  Perk(
    id: 'pp_craft',
    nameKey: 'pp_craft',
    descKey: 'pp_craft_desc',
    effect: PerkEffect.craftBonus,
    unlockAfterWorld: 0,
  ),
  Perk(
    id: 'pp_free_second_chance',
    nameKey: 'pp_free_second_chance',
    descKey: 'pp_free_second_chance_desc',
    effect: PerkEffect.freeSecondChance,
    unlockAfterWorld: 0,
  ),
];

/// Constellation (theo thứ tự trong [kConstellations]) → perk nó mở khoá.
///
/// Ánh xạ theo **index** chứ không theo id để thêm/bớt constellation không
/// phải sửa hai chỗ; số perk luôn khớp số constellation (có assert ở test).
Perk? prestigePerkForConstellationIndex(int index) =>
    index >= 0 && index < kPrestigePerks.length ? kPrestigePerks[index] : null;

/// Số perk được bật cùng lúc, theo prestige tier. **Bảng, không phải công
/// thức rải rác** — đây là chốt cân bằng duy nhất của I83.
///
/// Tier 0 giữ nguyên 2 slot như F14 gốc: prestige phải là thứ *mở ra* thêm
/// chỗ, không phải thứ người chơi đã có sẵn.
const Map<int, int> kPerkSlotsByPrestigeTier = {0: 2, 1: 3, 2: 3, 3: 4};

/// Trần cứng khi cộng dồn perk F14 + perk prestige + pet passive ([[I82]]).
const int kMaxPerkSlots = 4;

int perkSlotsForPrestigeTier(int tier) {
  if (tier <= 0) return kPerkSlotsByPrestigeTier[0]!;
  final exact = kPerkSlotsByPrestigeTier[tier];
  if (exact != null) return exact;
  // Tier cao hơn bảng → dùng bậc cao nhất đã khai báo, KHÔNG ngoại suy tăng
  // dần: bảng là chốt cân bằng, tier 99 không được thành 99 slot.
  return kPerkSlotsByPrestigeTier.values.reduce((a, b) => a > b ? a : b);
}

/// Perk prestige đã mở: constellation tương ứng đã sáng **và** đã prestige.
///
/// Ở tier 0 trả rỗng — perk vẫn hiện trên màn hình nhưng ở dạng khoá.
List<Perk> unlockedPrestigePerks({
  required int totalStars,
  required int prestigeTier,
}) {
  if (prestigeTier < 1) return const [];
  final out = <Perk>[];
  for (var i = 0; i < kConstellations.length; i++) {
    if (!isConstellationLit(kConstellations[i], totalStars)) continue;
    final perk = prestigePerkForConstellationIndex(i);
    if (perk != null) out.add(perk);
  }
  return out;
}
