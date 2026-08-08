import 'package:flutter/material.dart';

import '../logic/pop_collapse.dart' show GravityDirection;

/// I33 Daily Modifier Gauntlet: đúng 1 "luật chơi" cố định áp lên bàn Gauntlet
/// trong ngày, chọn theo epoch-day (xem [modifierForDay]) — không dùng
/// `Random()` để mọi thiết bị cùng ngày luôn gặp đúng 1 modifier như nhau.
class GauntletModifier {
  final String id;
  final IconData icon;
  final String nameKey;
  final String descKey;
  final bool disableUndo;
  final double? comboWindowOverride;
  final GravityDirection? gravityOverride;
  final int? colorCountOverride;
  final int? moveLimit;
  final int? minGroupSize;

  const GauntletModifier({
    required this.id,
    required this.icon,
    required this.nameKey,
    required this.descKey,
    this.disableUndo = false,
    this.comboWindowOverride,
    this.gravityOverride,
    this.colorCountOverride,
    this.moveLimit,
    this.minGroupSize,
  });
}

/// I60: fixed, increasingly restrictive five-stage expedition rules.
const List<GauntletModifier> kTreasureMapModifiers = [
  GauntletModifier(
    id: 'treasure_1',
    icon: Icons.filter_3_rounded,
    nameKey: 'treasure_stage_1',
    descKey: 'treasure_min_group_3',
    minGroupSize: 3,
  ),
  GauntletModifier(
    id: 'treasure_2',
    icon: Icons.looks_one_rounded,
    nameKey: 'treasure_stage_2',
    descKey: 'treasure_move_limit_14',
    moveLimit: 14,
  ),
  GauntletModifier(
    id: 'treasure_3',
    icon: Icons.filter_4_rounded,
    nameKey: 'treasure_stage_3',
    descKey: 'treasure_min_group_4',
    minGroupSize: 4,
  ),
  GauntletModifier(
    id: 'treasure_4',
    icon: Icons.timer_rounded,
    nameKey: 'treasure_stage_4',
    descKey: 'treasure_stage_4_rule',
    moveLimit: 12,
    minGroupSize: 3,
  ),
  GauntletModifier(
    id: 'treasure_5',
    icon: Icons.workspace_premium_rounded,
    nameKey: 'treasure_stage_5',
    descKey: 'treasure_stage_5_rule',
    moveLimit: 10,
    minGroupSize: 5,
  ),
];

// I80 Remix Levels cần tham chiếu lại từng modifier cụ thể trong 1
// const list khác (`kRemixLevels`) — index vào 1 const list (`kGauntletModifiers[i]`)
// không phải hằng số trong Dart, nên đặt tên riêng từng modifier rồi mới gom
// vào `kGauntletModifiers`.
const kModNoUndo = GauntletModifier(
  id: 'no_undo',
  icon: Icons.block_rounded,
  nameKey: 'gauntlet_modifier_no_undo_name',
  descKey: 'gauntlet_modifier_no_undo_desc',
  disableUndo: true,
);
const kModShortCombo = GauntletModifier(
  id: 'short_combo',
  icon: Icons.hourglass_bottom_rounded,
  nameKey: 'gauntlet_modifier_short_combo_name',
  descKey: 'gauntlet_modifier_short_combo_desc',
  comboWindowOverride: 1.5,
);
const kModFourColors = GauntletModifier(
  id: 'four_colors',
  icon: Icons.palette_rounded,
  nameKey: 'gauntlet_modifier_four_colors_name',
  descKey: 'gauntlet_modifier_four_colors_desc',
  colorCountOverride: 4,
);
const kModReverseGravity = GauntletModifier(
  id: 'reverse_gravity',
  icon: Icons.swap_vert_rounded,
  nameKey: 'gauntlet_modifier_reverse_gravity_name',
  descKey: 'gauntlet_modifier_reverse_gravity_desc',
  gravityOverride: GravityDirection.up,
);

const List<GauntletModifier> kGauntletModifiers = [
  kModNoUndo,
  kModShortCombo,
  kModFourColors,
  kModReverseGravity,
];

/// Modifier hôm nay = tuần hoàn đều theo [epochDay] % số modifier — thuần,
/// không phụ thuộc thời điểm gọi trong ngày.
GauntletModifier modifierForDay(int epochDay) =>
    kGauntletModifiers[epochDay % kGauntletModifiers.length];

/// I80 Remix Levels: 1 level campaign đã có sẵn ghép với 1
/// [GauntletModifier] có sẵn — không cần `nameKey` riêng, UI lấy tên hiển
/// thị qua `worldForLevel(levelId).nameKey` (đã có sẵn, tránh phát sinh
/// thêm i18n key mới cho từng entry).
class RemixLevel {
  final int levelId;
  final GauntletModifier modifier;

  const RemixLevel({required this.levelId, required this.modifier});
}

/// Curated, 1 entry gần giữa mỗi world cách quãng (world lẻ), modifier tuần
/// hoàn qua 4 modifier có sẵn của Gauntlet — đủ đa dạng luật chơi mà không
/// cần định nghĩa modifier riêng cho Remix.
const List<RemixLevel> kRemixLevels = [
  RemixLevel(levelId: 10, modifier: kModNoUndo),
  RemixLevel(levelId: 50, modifier: kModShortCombo),
  RemixLevel(levelId: 90, modifier: kModFourColors),
  RemixLevel(levelId: 130, modifier: kModReverseGravity),
  RemixLevel(levelId: 170, modifier: kModNoUndo),
  RemixLevel(levelId: 210, modifier: kModShortCombo),
  RemixLevel(levelId: 250, modifier: kModFourColors),
];
