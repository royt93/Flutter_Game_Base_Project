import 'package:flutter/material.dart';

/// Bảng màu & style neon dùng chung cho toàn app.
class NeonTheme {
  NeonTheme._();

  /// Font toàn app — Baloo2 (đủ glyph tiếng Việt + bo tròn vui mắt). Đặt làm
  /// default trong ThemeData (main.dart) → mọi Text mới kế thừa, khỏi lặp string.
  static const String fontFamily = 'Baloo2';

  // Hệ spacing chuẩn dùng toàn app (8 / 16 / 24).
  static const double s8 = 8;
  static const double s16 = 16;
  static const double s24 = 24;

  // Nền tối làm nổi gem phát sáng
  static const Color bgDark = Color(0xFF0A0A1A);
  static const Color bgDark2 = Color(0xFF14142E);
  static const Color panel = Color(0xFF1B1B3A);

  // 6 màu gem neon
  static const Color cyan = Color(0xFF00F0FF);
  static const Color magenta = Color(0xFFFF2BD6);
  static const Color lime = Color(0xFF39FF14);
  static const Color yellow = Color(0xFFFFE600);
  static const Color orange = Color(0xFFFF6B00);
  static const Color purple = Color(0xFFBC4BFF);

  static const List<Color> gemColors = [
    cyan,
    magenta,
    lime,
    yellow,
    orange,
    purple,
  ];

  /// Màu chủ đạo (accent) theo từng thế giới (1-based). Nguồn DUY NHẤT —
  /// dùng cho banner world, node map, background theo world, viền bàn.
  static const List<Color> worldAccents = [
    cyan, // World 1 — Cyan Nebula
    magenta, // World 2 — Magenta Pulse
    lime, // World 3 — Lime Circuit
    orange, // World 4 — Amber Comet
    purple, // World 5 — Violet Void
  ];

  static Color accentForWorld(int worldIndex) =>
      worldAccents[(worldIndex - 1) % worldAccents.length];

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDark, bgDark2, Color(0xFF1A0A2E)],
  );

  /// Đổ bóng phát sáng quanh widget theo màu neon.
  static List<BoxShadow> glow(Color color, {double blur = 18, double spread = 1}) {
    return [
      BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: blur, spreadRadius: spread),
      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: blur * 2, spreadRadius: spread),
    ];
  }
}
