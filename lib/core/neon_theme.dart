import 'package:flutter/material.dart';

/// Bảng màu & style dùng chung. Đợt revamp bright-casual (Candy-Crush): nền sáng
/// ấm, palette kẹo, thẻ trắng, chữ mực đậm. Giữ tên hằng cũ (cyan/magenta/…) để
/// khỏi rename hàng loạt callsite — giá trị đã tinh chỉnh sang tông "kẹo".
///
/// I15: bộ token nền/thẻ/mực (bg*/card*/ink*) là getter đổi theo [dark] — bật
/// lên dùng lại đúng bảng màu neon-dark gốc trước pivot. Callsite cũ gọi
/// `NeonTheme.ink`/`NeonTheme.card`/… không cần sửa gì, tự đổi theo flag.
class NeonTheme {
  NeonTheme._();

  /// true = bảng màu neon-dark gốc, false (mặc định) = bright-casual hiện tại.
  static bool dark = false;

  /// Font toàn app — Baloo2 (đủ glyph tiếng Việt + bo tròn vui mắt).
  static const String fontFamily = 'Baloo2';

  // Hệ spacing chuẩn (8 / 16 / 24).
  static const double s8 = 8;
  static const double s16 = 16;
  static const double s24 = 24;

  // --- Nền candy sky sáng / nền neon tối (gradient dọc) ---
  static const Color _bgTopLight = Color(0xFF7ED8FF); // xanh trời
  static const Color _bgMidLight = Color(0xFFB6A9FF); // tím lilac
  static const Color _bgBotLight = Color(0xFFFFC2E0); // hồng kẹo
  static const Color _bgTopDark = Color(0xFF2A2350);
  static const Color _bgMidDark = Color(0xFF1C1740);
  static const Color _bgBotDark = Color(0xFF1A0A2E); // nền tối gốc trước pivot

  static Color get bgTop => dark ? _bgTopDark : _bgTopLight;
  static Color get bgMid => dark ? _bgMidDark : _bgMidLight;
  static Color get bgBot => dark ? _bgBotDark : _bgBotLight;

  // --- Thẻ / panel sáng / tối ---
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _cardAltLight = Color(0xFFF2ECFF);
  static const Color _cardDark = Color(0xFF1B1B3A); // panel gốc trước pivot
  static const Color _cardAltDark = Color(0xFF14142E);

  static Color get card => dark ? _cardDark : _cardLight;
  static Color get cardAlt => dark ? _cardAltDark : _cardAltLight;
  static Color get panel => card; // alias tương thích callsite cũ

  // --- Mực chữ trên nền/thẻ ---
  static const Color _inkLight = Color(0xFF3A2E6B); // tím đậm, đọc rõ
  static const Color _inkSoftLight = Color(0xFF8579B0); // phụ/mô tả
  static const Color _inkDark = Color(0xFFEDEBFF); // trắng ngà trên nền tối
  static const Color _inkSoftDark = Color(0xFFA7A0D9);

  static Color get ink => dark ? _inkDark : _inkLight;
  static Color get inkSoft => dark ? _inkSoftDark : _inkSoftLight;

  // --- 7 màu block kiểu kẹo (saturated, thân thiện, dễ phân biệt) ---
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
  static const Color coral = Color(0xFFFF7A5C); // I79: World 13

  // Xám "disabled/muted" dùng chung cho nút/icon bị vô hiệu hoá.
  static const Color muted = Color(0xFFC9C3DA);

  // Node màn chưa mở khoá trên Level Select (viền/icon dùng chung 1 tông).
  static const Color lockedBorder = Color(0xFFBFC7D6);
  static const Color lockedFill = Color(0xFFEDEAF5);

  static const List<Color> gemColors = [
    cyan,
    magenta,
    lime,
    yellow,
    orange,
    purple,
    red, // I17-fix: world 10-11 sinh colorCount tới 7 — thiếu màu này khiến
    // colorIndex 6 alias trùng cyan qua modulo, 2 nhóm khác màu render y hệt.
  ];

  /// Gradient nền sáng candy dùng cho mọi screen (qua NeonBg).
  static LinearGradient get bgGradient => LinearGradient(
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
    // roy93~fix: BoxShadow vẽ 1 hình đặc cùng dạng box, không chỉ viền cạnh —
    // với box có fill trong suốt (vd panel bàn chơi alpha 0.25) thì phần lớn
    // shadow xuyên qua fill, nhuộm kín cả nội thất thay vì chỉ toả nhẹ ở
    // mép. `intensity` cho phép hạ alpha 3 lớp shadow ở nơi cần fill mờ mà
    // không đổi 14+ chỗ gọi khác đang dùng mặc định 1.0.
    double intensity = 1.0,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.9 * intensity),
        blurRadius: blur * 0.5,
        spreadRadius: spread * 0.4,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.5 * intensity),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.24 * intensity),
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
