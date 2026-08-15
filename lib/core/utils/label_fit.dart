import 'package:flutter/widgets.dart';

/// Cỡ chữ lớn nhất trong [candidates] mà **mọi từ** của [label] còn nằm gọn
/// trong [maxWidth].
///
/// Vì sao xét theo từ chứ không theo cả chuỗi: `Text` tự xuống dòng ở khoảng
/// trắng, nên chuỗi nhiều từ luôn vừa. Cái vỡ là **một từ đơn rộng hơn ô
/// chứa** — lúc đó Flutter ngắt giữa từ. Trên Mode Select tiếng Đức nó ra
/// "Doppelspiege" + "l" và "Zitronenwüst" + "e", nhìn như lỗi hiển thị.
///
/// Đo BỀ RỘNG từng từ, không lấy từ nhiều ký tự nhất. Bản đầu chọn từ theo
/// `.length` và sai: "WWW" hẹp hơn "mmmmm" về số ký tự nhưng rộng hơn về
/// pixel, nên từ thật sự tràn có thể bị bỏ qua.
///
/// Trả về phần tử cuối của [candidates] nếu không cỡ nào vừa: thà chữ nhỏ hơn
/// mức mong muốn còn hơn ngắt giữa từ.
double fitFontSizeForLongestWord(
  String label,
  double maxWidth, {
  List<double> candidates = const [11, 10, 9, 8],
  FontWeight fontWeight = FontWeight.w700,
  String? fontFamily = 'Baloo2',
  /// Khe đo, chỉ dùng cho test.
  ///
  /// `flutter test` không nạp Baloo2 mà thay bằng font có mọi glyph rộng bằng
  /// nhau, nên trong test "từ nhiều ký tự nhất" luôn trùng "từ rộng nhất" —
  /// không cách nào phân biệt bản đúng với bản sai. Có khe này thì tính chất
  /// "đo theo bề rộng" mới kiểm được.
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
