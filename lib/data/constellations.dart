import 'package:flutter/material.dart';

import '../core/neon_theme.dart';

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
