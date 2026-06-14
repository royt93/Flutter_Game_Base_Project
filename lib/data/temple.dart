import 'package:flutter/material.dart';
import '../core/neon_theme.dart';

/// Một cấp (tier) của hạng mục đền: chi phí Shard để xây + thưởng xu khi xong.
@immutable
class TempleTier {
  final int cost; // shard cần để lên tier này
  final int rewardCoins; // thưởng xu khi xây xong tier

  const TempleTier({required this.cost, required this.rewardCoins});
}

/// Một hạng mục công trình của "Đền Neon".
/// Vẽ bằng CustomPainter (không cần asset ảnh) — sáng dần theo tier đã xây.
@immutable
class TempleNode {
  final String id;
  final String nameKey; // key i18n tên
  final String descKey; // key i18n mô tả
  final Color accent; // tông neon của hạng mục
  final Offset pos; // vị trí tương đối [0..1] trên canvas đền
  final List<TempleTier> tiers;

  const TempleNode({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.accent,
    required this.pos,
    required this.tiers,
  });

  int get maxTier => tiers.length;
}

/// 6 hạng mục đền, mỗi cái 3 tier (chi phí tăng dần). Tổng = một mục tiêu dài hạn.
const List<TempleNode> kTempleNodes = [
  TempleNode(
    id: 'gate',
    nameKey: 'temple_gate',
    descKey: 'temple_gate_desc',
    accent: NeonTheme.cyan,
    pos: Offset(0.5, 0.86),
    tiers: [
      TempleTier(cost: 6, rewardCoins: 30),
      TempleTier(cost: 14, rewardCoins: 60),
      TempleTier(cost: 28, rewardCoins: 120),
    ],
  ),
  TempleNode(
    id: 'pillarL',
    nameKey: 'temple_pillar',
    descKey: 'temple_pillar_desc',
    accent: NeonTheme.magenta,
    pos: Offset(0.26, 0.6),
    tiers: [
      TempleTier(cost: 8, rewardCoins: 30),
      TempleTier(cost: 18, rewardCoins: 70),
      TempleTier(cost: 34, rewardCoins: 130),
    ],
  ),
  TempleNode(
    id: 'pillarR',
    nameKey: 'temple_pillar',
    descKey: 'temple_pillar_desc',
    accent: NeonTheme.magenta,
    pos: Offset(0.74, 0.6),
    tiers: [
      TempleTier(cost: 8, rewardCoins: 30),
      TempleTier(cost: 18, rewardCoins: 70),
      TempleTier(cost: 34, rewardCoins: 130),
    ],
  ),
  TempleNode(
    id: 'altar',
    nameKey: 'temple_altar',
    descKey: 'temple_altar_desc',
    accent: NeonTheme.lime,
    pos: Offset(0.5, 0.62),
    tiers: [
      TempleTier(cost: 12, rewardCoins: 40),
      TempleTier(cost: 26, rewardCoins: 90),
      TempleTier(cost: 48, rewardCoins: 160),
    ],
  ),
  TempleNode(
    id: 'spire',
    nameKey: 'temple_spire',
    descKey: 'temple_spire_desc',
    accent: NeonTheme.orange,
    pos: Offset(0.5, 0.34),
    tiers: [
      TempleTier(cost: 16, rewardCoins: 50),
      TempleTier(cost: 34, rewardCoins: 110),
      TempleTier(cost: 60, rewardCoins: 200),
    ],
  ),
  TempleNode(
    id: 'core',
    nameKey: 'temple_core',
    descKey: 'temple_core_desc',
    accent: NeonTheme.purple,
    pos: Offset(0.5, 0.14),
    tiers: [
      TempleTier(cost: 24, rewardCoins: 80),
      TempleTier(cost: 50, rewardCoins: 170),
      TempleTier(cost: 90, rewardCoins: 320),
    ],
  ),
];
