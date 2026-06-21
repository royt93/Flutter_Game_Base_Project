import 'package:neon_jewels/core/neon_theme.dart';
import 'package:flutter/material.dart';

/// Wave 20.3 — Cây tiến trình meta (Progression Tree).
/// 3 nút mở khoá hiệu ứng visual — KHÔNG p2w (chỉ cosmetic).
class PtNode {
  final String id;
  final String titleKey; // i18n key
  final String descKey;
  final int starCost; // tổng sao cần (0 = dùng goldCost)
  final int goldCost; // số Gold Milestone cần
  final Color color;
  const PtNode({
    required this.id,
    required this.titleKey,
    required this.descKey,
    this.starCost = 0,
    this.goldCost = 0,
    required this.color,
  });
}

const List<PtNode> kPtNodes = [
  PtNode(
    id: 'radiant',
    titleKey: 'pt_radiant_title',
    descKey: 'pt_radiant_desc',
    starCost: 50,
    color: NeonTheme.cyan,
  ),
  PtNode(
    id: 'blazing',
    titleKey: 'pt_blazing_title',
    descKey: 'pt_blazing_desc',
    starCost: 150,
    color: NeonTheme.orange,
  ),
  PtNode(
    id: 'prestige',
    titleKey: 'pt_prestige_title',
    descKey: 'pt_prestige_desc',
    goldCost: 5,
    color: NeonTheme.yellow,
  ),
];

PtNode? ptNodeById(String id) {
  for (final n in kPtNodes) {
    if (n.id == id) return n;
  }
  return null;
}
