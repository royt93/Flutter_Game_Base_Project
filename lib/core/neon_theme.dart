import 'package:flutter/material.dart';

/// Bảng màu & style neon dùng chung cho toàn app.
class NeonTheme {
  NeonTheme._();

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

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDark, bgDark2, Color(0xFF1A0A2E)],
  );

  /// Đổ bóng phát sáng quanh widget theo màu neon.
  static List<BoxShadow> glow(Color color, {double blur = 18, double spread = 1}) {
    return [
      BoxShadow(color: color.withOpacity(0.8), blurRadius: blur, spreadRadius: spread),
      BoxShadow(color: color.withOpacity(0.4), blurRadius: blur * 2, spreadRadius: spread),
    ];
  }
}
