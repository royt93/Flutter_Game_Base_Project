import 'package:flutter/material.dart';

/// Shared color palette & styles. Bright-casual (Candy-Crush-style) revamp:
/// warm light background, candy palette, white cards, bold ink text. Keeps
/// the old constant names (cyan/magenta/…) to avoid a mass callsite rename —
/// the values themselves have been retuned to a "candy" tone.
///
/// The bg*/card*/ink* background/card/ink token set are getters that switch
/// on [dark] — flip it on to fall back to the original neon-dark palette from
/// before the pivot. Existing callsites calling `NeonTheme.ink`/`NeonTheme.card`/…
/// need no changes; they switch automatically with the flag.
class NeonTheme {
  NeonTheme._();

  /// true = original neon-dark palette, false (default) = current bright-casual look.
  static bool dark = false;

  /// Whether the OS "Reduce Motion" accessibility flag is on — check this
  /// before running a purely decorative animation (shader background,
  /// pop-in, scale-on-press...) and skip/shorten it for motion-sensitive
  /// users. One central helper so every animated widget in the kit checks
  /// the same flag the same way.
  static bool reducedMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  /// Motion-language convention for ephemeral/entrance animations (IDEA-21)
  /// — pick the curve by what KIND of moment it is, not by habit:
  /// - **Celebration/reward** (confetti trigger, combo/score text, a won
  ///   dialog, a reward popup, "this thing you did was great") — an
  ///   overshoot curve (`Curves.easeOutBack` or similar), 150-320ms. Reads
  ///   as playful/bouncy. Examples already following this:
  ///   `RewardPopup`/`NeonDialog`'s entrance, `FloatingComboText`'s
  ///   scale pop-in (IDEA-19), `ToastBanner`'s slide-in, `RibbonBadge`'s
  ///   pop-in (IDEA-27), `StreakCounter`/`ProgressBarStars`/
  ///   `IconBadgeButton`'s "just earned/changed" pop (ENH-31/32/IDEA-16).
  /// - **Status/warning** (a network/offline banner, a system-level
  ///   notice — "pay attention, something changed, not a reward") — a
  ///   flat curve (`Curves.easeOut`/`easeInOut`, no overshoot). Reads as
  ///   serious/neutral. Example: `NetworkStatusBanner`.
  /// - **Physics-driven motion** (confetti fall/spin, a coin's flight arc)
  ///   is exempt — it's a simulated trajectory, not an "entrance curve" in
  ///   the UI sense above.
  ///
  /// Every entrance/implicit animation should set an EXPLICIT `curve:` —
  /// never rely on an implicit widget's default (`Curves.linear`), even
  /// for the flat/status case, so the choice reads as deliberate in the
  /// code rather than "nobody set one".

  /// App-wide font — Baloo2 (full Vietnamese glyph coverage + a friendly rounded look).
  static const String fontFamily = 'Baloo2';

  // Hệ spacing chuẩn (8 / 16 / 24).
  static const double s8 = 8;
  static const double s16 = 16;
  static const double s24 = 24;

  // --- Nền candy sky sáng / nền neon tối (gradient dọc) ---
  // Mutable (not const) so a JSON reskin (see exportPalette/importPalette
  // below) can override every field at runtime with zero call-site changes.
  static Color _bgTopLight = const Color(0xFF7ED8FF); // xanh trời
  static Color _bgMidLight = const Color(0xFFB6A9FF); // tím lilac
  static Color _bgBotLight = const Color(0xFFFFC2E0); // hồng kẹo
  static Color _bgTopDark = const Color(0xFF2A2350);
  static Color _bgMidDark = const Color(0xFF1C1740);
  static Color _bgBotDark = const Color(0xFF1A0A2E); // nền tối gốc trước pivot

  static Color get bgTop => dark ? _bgTopDark : _bgTopLight;
  static Color get bgMid => dark ? _bgMidDark : _bgMidLight;
  static Color get bgBot => dark ? _bgBotDark : _bgBotLight;

  // --- Thẻ / panel sáng / tối ---
  static Color _cardLight = const Color(0xFFFFFFFF);
  static Color _cardAltLight = const Color(0xFFF2ECFF);
  static Color _cardDark = const Color(0xFF1B1B3A); // panel gốc trước pivot
  static Color _cardAltDark = const Color(0xFF14142E);

  static Color get card => dark ? _cardDark : _cardLight;
  static Color get cardAlt => dark ? _cardAltDark : _cardAltLight;
  static Color get panel => card; // alias tương thích callsite cũ

  // --- Mực chữ trên nền/thẻ ---
  static Color _inkLight = const Color(0xFF3A2E6B); // tím đậm, đọc rõ
  static Color _inkSoftLight = const Color(0xFF8579B0); // phụ/mô tả
  static Color _inkDark = const Color(0xFFEDEBFF); // trắng ngà trên nền tối
  static Color _inkSoftDark = const Color(0xFFA7A0D9);

  static Color get ink => dark ? _inkDark : _inkLight;
  static Color get inkSoft => dark ? _inkSoftDark : _inkSoftLight;

  // --- 7 màu block kiểu kẹo (saturated, thân thiện, dễ phân biệt) ---
  static Color cyan = const Color(0xFF35C4F0); // xanh dương kẹo
  static Color magenta = const Color(0xFFFF6FC1); // hồng kẹo
  static Color lime = const Color(0xFF5FD35A); // xanh lá kẹo
  static Color yellow = const Color(0xFFFFD23F); // vàng kẹo
  static Color orange = const Color(0xFFFF9F3A); // cam kẹo
  static Color purple = const Color(0xFFB36BFF); // tím kẹo

  // Accent UI phụ (icon/nút) — không phải màu block.
  static Color blue = const Color(0xFF4DA6FF);
  static Color pink = const Color(0xFFFF8AD0);
  static Color teal = const Color(0xFF2DD4C4);
  static Color red = const Color(0xFFFF6B6B);
  static Color indigo = const Color(0xFF6C7BFF);
  static Color gold = const Color(0xFFFFB300);
  static Color coral = const Color(
    0xFFFF7A5C,
  ); // extra accent, unused by any current screen

  // Xám "disabled/muted" dùng chung cho nút/icon bị vô hiệu hoá.
  static Color muted = const Color(0xFFC9C3DA);

  // Node màn chưa mở khoá trên Level Select (viền/icon dùng chung 1 tông).
  static Color lockedBorder = const Color(0xFFBFC7D6);
  static Color lockedFill = const Color(0xFFEDEAF5);

  static List<Color> get gemColors => [
    cyan,
    magenta,
    lime,
    yellow,
    orange,
    purple,
    red, // 7th color — without it, a caller needing colorIndex 6 aliases
    // back to cyan via modulo, and two different-color groups would render
    // identically.
  ];

  /// Every color field above as `#RRGGBB` hex strings, keyed by field name
  /// (private `_xxxLight`/`_xxxDark` fields are exposed without their
  /// leading underscore). Known limitation: alpha is dropped — every color
  /// in this palette is fully opaque today, so re-importing always yields
  /// `0xFF` alpha even if a future field weren't.
  static Map<String, String> exportPalette() => {
    'bgTopLight': _hex(_bgTopLight),
    'bgMidLight': _hex(_bgMidLight),
    'bgBotLight': _hex(_bgBotLight),
    'bgTopDark': _hex(_bgTopDark),
    'bgMidDark': _hex(_bgMidDark),
    'bgBotDark': _hex(_bgBotDark),
    'cardLight': _hex(_cardLight),
    'cardAltLight': _hex(_cardAltLight),
    'cardDark': _hex(_cardDark),
    'cardAltDark': _hex(_cardAltDark),
    'inkLight': _hex(_inkLight),
    'inkSoftLight': _hex(_inkSoftLight),
    'inkDark': _hex(_inkDark),
    'inkSoftDark': _hex(_inkSoftDark),
    'cyan': _hex(cyan),
    'magenta': _hex(magenta),
    'lime': _hex(lime),
    'yellow': _hex(yellow),
    'orange': _hex(orange),
    'purple': _hex(purple),
    'blue': _hex(blue),
    'pink': _hex(pink),
    'teal': _hex(teal),
    'red': _hex(red),
    'indigo': _hex(indigo),
    'gold': _hex(gold),
    'coral': _hex(coral),
    'muted': _hex(muted),
    'lockedBorder': _hex(lockedBorder),
    'lockedFill': _hex(lockedFill),
  };

  /// Overwrites every known field present in [json] (value must be a
  /// `#RRGGBB`/`RRGGBB` hex `String`) — a studio "reskin" JSON. Keys absent
  /// from [json] keep their current value (partial reskins are fine).
  /// Unknown keys and unparsable values are silently ignored rather than
  /// thrown — a forward/backward-compatible palette file.
  static void importPalette(Map<String, Object?> json) {
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is! String) continue;
      final color = _tryParseHex(value);
      if (color == null) continue;
      switch (entry.key) {
        case 'bgTopLight':
          _bgTopLight = color;
        case 'bgMidLight':
          _bgMidLight = color;
        case 'bgBotLight':
          _bgBotLight = color;
        case 'bgTopDark':
          _bgTopDark = color;
        case 'bgMidDark':
          _bgMidDark = color;
        case 'bgBotDark':
          _bgBotDark = color;
        case 'cardLight':
          _cardLight = color;
        case 'cardAltLight':
          _cardAltLight = color;
        case 'cardDark':
          _cardDark = color;
        case 'cardAltDark':
          _cardAltDark = color;
        case 'inkLight':
          _inkLight = color;
        case 'inkSoftLight':
          _inkSoftLight = color;
        case 'inkDark':
          _inkDark = color;
        case 'inkSoftDark':
          _inkSoftDark = color;
        case 'cyan':
          cyan = color;
        case 'magenta':
          magenta = color;
        case 'lime':
          lime = color;
        case 'yellow':
          yellow = color;
        case 'orange':
          orange = color;
        case 'purple':
          purple = color;
        case 'blue':
          blue = color;
        case 'pink':
          pink = color;
        case 'teal':
          teal = color;
        case 'red':
          red = color;
        case 'indigo':
          indigo = color;
        case 'gold':
          gold = color;
        case 'coral':
          coral = color;
        case 'muted':
          muted = color;
        case 'lockedBorder':
          lockedBorder = color;
        case 'lockedFill':
          lockedFill = color;
        default:
        // unknown key — ignored, forward-compatible with future palette additions.
      }
    }
  }

  static String _hex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color? _tryParseHex(String value) {
    var s = value.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length != 6) return null;
    final parsed = int.tryParse(s, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  /// Bright candy background gradient used across every screen (via NeonBg).
  static LinearGradient get bgGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMid, bgBot],
  );

  /// Colored glow shadow around a widget. 3 layers: a sharp bright core +
  /// a mid halo + a wide soft glow → a soft bloom in a glossy-candy style.
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

  /// "Chunky" drop shadow for casual cards/buttons: a soft shadow cast
  /// downward to create a raised-block look.
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
