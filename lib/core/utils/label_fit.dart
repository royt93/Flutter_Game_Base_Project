import 'package:flutter/widgets.dart';

/// Cỡ chữ lớn nhất trong [candidates] mà **từ dài nhất** của [label] còn nằm
/// gọn trong [maxWidth].
///
/// Vì sao đo theo từ dài nhất chứ không theo cả chuỗi: `Text` tự xuống dòng ở
/// khoảng trắng, nên chuỗi nhiều từ luôn vừa. Cái vỡ là **một từ đơn dài hơn ô
/// chứa** — lúc đó Flutter ngắt giữa từ. Trên Mode Select tiếng Đức nó ra
/// "Doppelspiege" + "l" và "Zitronenwüst" + "e", nhìn như lỗi hiển thị.
///
/// Trả về phần tử cuối của [candidates] nếu không cỡ nào vừa: thà chữ nhỏ hơn
/// mức mong muốn còn hơn ngắt giữa từ.
double fitFontSizeForLongestWord(
  String label,
  double maxWidth, {
  List<double> candidates = const [11, 10, 9, 8],
  FontWeight fontWeight = FontWeight.w700,
  String? fontFamily = 'Baloo2',
}) {
  assert(candidates.isNotEmpty, 'cần ít nhất một cỡ chữ');
  final words = label.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty || maxWidth <= 0) return candidates.first;
  final longest = words.reduce((a, b) => a.length >= b.length ? a : b);

  for (final size in candidates) {
    final painter = TextPainter(
      text: TextSpan(
        text: longest,
        style: TextStyle(
          fontSize: size,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (painter.width <= maxWidth) return size;
  }
  return candidates.last;
}
