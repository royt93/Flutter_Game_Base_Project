import 'package:flutter/widgets.dart';

/// The largest font size in [candidates] for which **every word** of [label]
/// still fits within [maxWidth].
///
/// Why this checks per-word rather than the whole string: `Text` wraps at
/// whitespace on its own, so a multi-word string always fits. What breaks is
/// **a single word wider than the container** — that's when Flutter breaks
/// mid-word. On the German Mode Select screen this produced
/// "Doppelspiege" + "l" and "Zitronenwüst" + "e", which looks like a display bug.
///
/// Measures each word's WIDTH, not the word with the most characters. The
/// first version picked a word by `.length` and was wrong: "WWW" has fewer
/// characters than "mmmmm" but is wider in pixels, so the word that actually
/// overflows could be missed.
///
/// Returns the last element of [candidates] if no size fits: a smaller font
/// than intended beats breaking in the middle of a word.
double fitFontSizeForLongestWord(
  String label,
  double maxWidth, {
  List<double> candidates = const [11, 10, 9, 8],
  FontWeight fontWeight = FontWeight.w700,
  String? fontFamily = 'Baloo2',
  /// Test-only measurement seam.
  ///
  /// `flutter test` doesn't load Baloo2 and substitutes a font where every
  /// glyph has equal width, so in tests "word with the most characters"
  /// always coincides with "widest word" — there's no way to tell a correct
  /// implementation from a broken one. This seam is what lets the
  /// "measures by width" property actually be tested.
  @visibleForTesting double Function(String word, double fontSize)? measureWord,
}) {
  assert(candidates.isNotEmpty, 'cần ít nhất một cỡ chữ');
  final words = label
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty || maxWidth <= 0) return candidates.first;

  double measure(String word, double size) {
    if (measureWord != null) return measureWord(word, size);
    final painter = TextPainter(
      text: TextSpan(
        text: word,
        style: TextStyle(
          fontSize: size,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  double widestWord(double size) {
    var widest = 0.0;
    for (final word in words) {
      final w = measure(word, size);
      if (w > widest) widest = w;
    }
    return widest;
  }

  for (final size in candidates) {
    if (widestWord(size) <= maxWidth) return size;
  }
  return candidates.last;
}
