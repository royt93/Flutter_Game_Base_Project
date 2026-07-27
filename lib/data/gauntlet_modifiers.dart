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

  const GauntletModifier({
    required this.id,
    required this.icon,
    required this.nameKey,
    required this.descKey,
    this.disableUndo = false,
    this.comboWindowOverride,
    this.gravityOverride,
    this.colorCountOverride,
  });
}

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
