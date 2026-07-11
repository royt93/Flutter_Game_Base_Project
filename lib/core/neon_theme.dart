import 'package:flutter/material.dart';

/// Bảng màu & style dùng chung. Đợt revamp bright-casual (Candy-Crush): nền sáng
/// ấm, palette kẹo, thẻ trắng, chữ mực đậm. Giữ tên hằng cũ (cyan/magenta/…) để
/// khỏi rename hàng loạt callsite — giá trị đã tinh chỉnh sang tông "kẹo".
class NeonTheme {
  NeonTheme._();

  /// Font toàn app — Baloo2 (đủ glyph tiếng Việt + bo tròn vui mắt).
  static const String fontFamily = 'Baloo2';

  // Hệ spacing chuẩn (8 / 16 / 24).
  static const double s8 = 8;
  static const double s16 = 16;
  static const double s24 = 24;

  // --- Nền sáng candy sky (gradient dọc) ---
  static const Color bgTop = Color(0xFF7ED8FF); // xanh trời
  static const Color bgMid = Color(0xFFB6A9FF); // tím lilac
  static const Color bgBot = Color(0xFFFFC2E0); // hồng kẹo

  // --- Thẻ / panel sáng ---
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFF2ECFF);
  static const Color panel = Color(0xFFFFFFFF); // alias tương thích callsite cũ

  // --- Mực chữ trên nền/thẻ sáng ---
  static const Color ink = Color(0xFF3A2E6B); // tím đậm, đọc rõ
  static const Color inkSoft = Color(0xFF8579B0); // phụ/mô tả

  // Giữ 2 hằng nền tối cũ cho callsite chưa chuyển (game canvas dùng board panel).
  static const Color bgDark = Color(0xFF2A2350);
  static const Color bgDark2 = Color(0xFF1C1740);

  // --- 6 màu block kiểu kẹo (saturated, thân thiện, dễ phân biệt) ---
  static const Color cyan = Color(0xFF35C4F0); // xanh dương kẹo
  static const Color magenta = Color(0xFFFF6FC1); // hồng kẹo
  static const Color lime = Color(0xFF5FD35A); // xanh lá kẹo
  static const Color yellow = Color(0xFFFFD23F); // vàng kẹo
  static const Color orange = Color(0xFFFF9F3A); // cam kẹo
  static const Color purple = Color(0xFFB36BFF); // tím kẹo

  // Accent UI phụ (icon/nút) — không phải màu block.
  static const Color blue = Color(0xFF4DA6FF);
  static const Color pink = Color(0xFFFF8AD0);
  static const Color teal = Color(0xFF2DD4C4);
  static const Color red = Color(0xFFFF6B6B);
  static const Color indigo = Color(0xFF6C7BFF);
  static const Color gold = Color(0xFFFFB300);

  static const List<Color> gemColors = [
    cyan,
    magenta,
    lime,
    yellow,
    orange,
    purple,
  ];

  /// Gradient nền sáng candy dùng cho mọi screen (qua NeonBg).
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMid, bgBot],
  );

  /// Đổ bóng phát sáng quanh widget theo màu. 3 lớp: lõi sáng gắt + vầng giữa +
  /// quầng rộng mờ → bloom mềm kiểu ánh kẹo bóng.
  static List<BoxShadow> glow(
    Color color, {
    double blur = 18,
    double spread = 1,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.9),
        blurRadius: blur * 0.5,
        spreadRadius: spread * 0.4,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.5),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.24),
        blurRadius: blur * 2.4,
        spreadRadius: spread * 1.6,
      ),
    ];
  }

  /// Đổ bóng "chunky" cho thẻ/nút casual: bóng mềm đổ xuống dưới tạo khối nổi.
  static List<BoxShadow> drop({double y = 4, double blur = 10}) {
    return [
      BoxShadow(
        color: ink.withValues(alpha: 0.18),
        offset: Offset(0, y),
        blurRadius: blur,
      ),
    ];
  }
}
