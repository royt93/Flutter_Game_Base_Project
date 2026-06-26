import 'package:flutter/material.dart';
import '../core/neon_theme.dart';

/// Trang trí (cosmetics) — skin gem + theme bàn, mua bằng xu ở Cửa Hàng.
/// KHÔNG ảnh hưởng gameplay (6 màu luôn phân biệt được): chỉ đổi bộ màu, hình
/// dạng gem và tông viền/ô của bàn.

/// Bộ skin cho gem: 6 màu (theo GemColor 0..5), một "họ hình" và hệ số glow.
/// [shapeFamily]: 0 = lá bài (♥♦♣♠★●), 1 = hình học, 2 = tinh thể (gem cut).
class GemSkin {
  final String id;
  final String name; // tên hiển thị (proper noun, không qua i18n)
  final int price; // 0 = miễn phí (mặc định, sở hữu sẵn)
  final List<Color> colors; // đúng 6 màu
  final int shapeFamily; // 0..2
  final double glowScale; // hệ số bán kính glow (1.0 = chuẩn)

  const GemSkin({
    required this.id,
    required this.name,
    required this.price,
    required this.colors,
    required this.shapeFamily,
    required this.glowScale,
  });
}

/// Theme bàn: 2 màu viền neon + tông phủ ô + accent nền.
class BoardTheme {
  final String id;
  final String name;
  final int price;
  final Color border1; // viền trong (đậm)
  final Color border2; // viền ngoài (mờ)
  final Color slotTint; // tông phủ nhẹ lên ô bàn
  final Color accent; // màu accent (preview / nền)

  const BoardTheme({
    required this.id,
    required this.name,
    required this.price,
    required this.border1,
    required this.border2,
    required this.slotTint,
    required this.accent,
  });
}

/// 6 skin gem. [0] = mặc định miễn phí (đúng màu/hình gốc của game).
const List<GemSkin> kGemSkins = [
  GemSkin(
    id: 'classic',
    name: 'Classic',
    price: 0,
    colors: NeonTheme.gemColors, // cyan/magenta/lime/yellow/orange/purple
    shapeFamily: 0,
    glowScale: 1.0,
  ),
  GemSkin(
    id: 'aurora',
    name: 'Aurora',
    price: 300,
    colors: [
      Color(0xFF7DF9FF),
      Color(0xFFFF9EE6),
      Color(0xFFA8FF8F),
      Color(0xFFFFF59E),
      Color(0xFFFFC58F),
      Color(0xFFD7B3FF),
    ],
    shapeFamily: 1,
    glowScale: 1.1,
  ),
  GemSkin(
    id: 'inferno',
    name: 'Inferno',
    price: 500,
    colors: [
      Color(0xFF18E0FF),
      Color(0xFFFF2D6E),
      Color(0xFFCBFF2D),
      Color(0xFFFFC400),
      Color(0xFFFF5A1F),
      Color(0xFFB02DFF),
    ],
    shapeFamily: 2,
    glowScale: 1.3,
  ),
  GemSkin(
    id: 'candy',
    name: 'Candy',
    price: 500,
    colors: [
      Color(0xFF5FE0FF),
      Color(0xFFFF6FC8),
      Color(0xFF66E6A0),
      Color(0xFFFFE26F),
      Color(0xFFFF9F6F),
      Color(0xFFB98CFF),
    ],
    shapeFamily: 0,
    glowScale: 1.0,
  ),
  GemSkin(
    id: 'frost',
    name: 'Frost',
    price: 700,
    colors: [
      Color(0xFF9EE7FF),
      Color(0xFFE08CFF),
      Color(0xFF8CFFD6),
      Color(0xFFEAFAFF),
      Color(0xFF7AC8FF),
      Color(0xFFB0A8FF),
    ],
    shapeFamily: 1,
    glowScale: 0.9,
  ),
  GemSkin(
    id: 'void',
    name: 'Void',
    price: 900,
    colors: [
      Color(0xFF00C2D6),
      Color(0xFFE01FA8),
      Color(0xFF49D62B),
      Color(0xFFD6B800),
      Color(0xFFD65A12),
      Color(0xFF8A2BE2),
    ],
    shapeFamily: 2,
    glowScale: 1.15,
  ),
];

/// 6 theme bàn. [0] = mặc định miễn phí (đúng tông cyan/purple gốc).
const List<BoardTheme> kBoardThemes = [
  BoardTheme(
    id: 'midnight',
    name: 'Midnight',
    price: 0,
    border1: Color(0xFF00F0FF),
    border2: Color(0xFFBC4BFF),
    slotTint: Color(0x00000000),
    accent: NeonTheme.cyan,
  ),
  BoardTheme(
    id: 'sunset',
    name: 'Sunset',
    price: 300,
    border1: Color(0xFFFF6B00),
    border2: Color(0xFFFF2BD6),
    slotTint: Color(0x14FF6B00),
    accent: NeonTheme.orange,
  ),
  BoardTheme(
    id: 'forest',
    name: 'Forest',
    price: 400,
    border1: Color(0xFF39FF14),
    border2: Color(0xFF00F0AA),
    slotTint: Color(0x1439FF14),
    accent: NeonTheme.lime,
  ),
  BoardTheme(
    id: 'ocean',
    name: 'Ocean',
    price: 400,
    border1: Color(0xFF18C8FF),
    border2: Color(0xFF2B6BFF),
    slotTint: Color(0x1418C8FF),
    accent: Color(0xFF18C8FF),
  ),
  BoardTheme(
    id: 'rose',
    name: 'Rose',
    price: 600,
    border1: Color(0xFFFF2BD6),
    border2: Color(0xFFFF6FA8),
    slotTint: Color(0x14FF2BD6),
    accent: NeonTheme.magenta,
  ),
  BoardTheme(
    id: 'mono',
    name: 'Mono',
    price: 800,
    border1: Color(0xFFE6E6FF),
    border2: Color(0xFF9A9AC8),
    slotTint: Color(0x10FFFFFF),
    accent: Color(0xFFBFC4FF),
  ),
];

GemSkin gemSkinById(String id) =>
    kGemSkins.firstWhere((s) => s.id == id, orElse: () => kGemSkins.first);

BoardTheme boardThemeById(String id) => kBoardThemes.firstWhere(
  (t) => t.id == id,
  orElse: () => kBoardThemes.first,
);

/// Trang trí ĐANG áp dụng — đọc bởi tầng render (Flame) mà không cần Get.find
/// mỗi khung hình. GameController cập nhật 2 trường này khi load / khi đổi chọn.
class ActiveCosmetics {
  ActiveCosmetics._();

  static GemSkin gemSkin = kGemSkins.first;
  static BoardTheme boardTheme = kBoardThemes.first;

  // Wave 20.3 — Progression Tree effects
  static double particleBurstMultiplier =
      1.0; // 1.0/1.5/2.0 theo node radiant/blazing
  static bool prestigeUnlocked = false; // node prestige

  /// W22.1 — "giảm hiệu ứng động" (accessibility); render đọc tĩnh mỗi frame
  /// (không Get.find). Cập nhật bởi GameController khi load/toggle.
  static bool reducedMotion = false;
}
