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

const List<GauntletModifier> kGauntletModifiers = [
  GauntletModifier(
    id: 'no_undo',
    icon: Icons.block_rounded,
    nameKey: 'gauntlet_modifier_no_undo_name',
    descKey: 'gauntlet_modifier_no_undo_desc',
    disableUndo: true,
  ),
  GauntletModifier(
    id: 'short_combo',
    icon: Icons.hourglass_bottom_rounded,
    nameKey: 'gauntlet_modifier_short_combo_name',
    descKey: 'gauntlet_modifier_short_combo_desc',
    comboWindowOverride: 1.5,
  ),
  GauntletModifier(
    id: 'four_colors',
    icon: Icons.palette_rounded,
    nameKey: 'gauntlet_modifier_four_colors_name',
    descKey: 'gauntlet_modifier_four_colors_desc',
    colorCountOverride: 4,
  ),
  GauntletModifier(
    id: 'reverse_gravity',
    icon: Icons.swap_vert_rounded,
    nameKey: 'gauntlet_modifier_reverse_gravity_name',
    descKey: 'gauntlet_modifier_reverse_gravity_desc',
    gravityOverride: GravityDirection.up,
  ),
];

/// Modifier hôm nay = tuần hoàn đều theo [epochDay] % số modifier — thuần,
/// không phụ thuộc thời điểm gọi trong ngày.
GauntletModifier modifierForDay(int epochDay) =>
    kGauntletModifiers[epochDay % kGauntletModifiers.length];
