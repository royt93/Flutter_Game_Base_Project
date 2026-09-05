import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_base_game/core/utils/label_fit.dart';

/// Nhãn ô trên Mode Select rộng cố định 60px. Chuỗi nhiều từ tự xuống dòng ở
/// khoảng trắng nên luôn vừa; cái vỡ là **một từ đơn dài hơn 60px** — Flutter
/// ngắt giữa từ. Tiếng Đức sau đợt dịch cho ra đúng cảnh đó trên máy thật:
/// "Doppelspiege" + "l", "Zitronenwüst" + "e".
///
/// **Test không được kỳ vọng con số tuyệt đối.** `flutter test` không nạp
/// Baloo2 mà dùng font thay thế cỡ chữ ô vuông, nên bề rộng ở đây khác hẳn
/// trên máy. Bản đầu của file này viết `expect(..., 11)` cho
/// "Mode na Time Attack" và đỏ vì lý do đó — kỳ vọng sai, không phải hàm sai.
/// Mọi ca dưới vì thế kiểm **hợp đồng**, đo lại bằng chính `TextPainter`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 60.0;
  const candidates = [11.0, 10.0, 9.0, 8.0];

  double widthOf(String word, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: word,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontFamily: 'Baloo2',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  /// Đáp án đúng theo định nghĩa: cỡ lớn nhất mà từ dài nhất còn vừa, không
  /// có thì cỡ nhỏ nhất.
  double expected(String label) {
    final words = label.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return candidates.first;
    for (final size in candidates) {
      final widest = words.map((w) => widthOf(w, size)).reduce((a, b) => a > b ? a : b);
      if (widest <= width) return size;
    }
    return candidates.last;
  }

  group('khớp định nghĩa "cỡ lớn nhất mà từ dài nhất còn vừa"', () {
    const labels = [
      'Zen',
      'Doppelspiegel',
      'Zitronenwüste',
      'Bonbonwiese',
      'Mode na Time Attack',
      'Boss-Ansturm',
      'Talaan ng Milestone',
    ];
    for (final label in labels) {
      test(label, () {
        expect(fitFontSizeForLongestWord(label, width), expected(label));
      });
    }
  });

  test('chọn theo BỀ RỘNG, không theo số ký tự', () {
    // Không dùng font thật: `flutter test` thay bằng font mọi glyph rộng bằng
    // nhau, nên ở đó "nhiều ký tự nhất" luôn trùng "rộng nhất" và ca này
    // không thể đỏ. Đo giả: 'W' rộng gấp 5 lần 'i'.
    double fake(String word, double size) =>
        size * word.split('').fold<double>(0, (a, ch) => a + (ch == 'W' ? 5 : 1));

    // 'WWW' = 15 đơn vị/cỡ, 'iiiiiiii' = 8 — từ NGẮN hơn lại rộng hơn.
    const label = 'WWW iiiiiiii';
    // Ở cỡ 11: 15*11 = 165 > 60. Cỡ 8: 15*8 = 120 > 60. Không cỡ nào vừa.
    expect(
      fitFontSizeForLongestWord(label, width, measureWord: fake),
      candidates.last,
    );
    // Bản sai (lấy từ theo .length) sẽ đo 'iiiiiiii': 8*8 = 64 > 60 -> cũng 8.
    // Nên dùng thêm ô rộng hơn để hai bản KHÁC nhau rõ ràng:
    // 'iiiiiiii' vừa ở cỡ 7 (56 <= 60) còn 'WWW' thì không.
    expect(
      fitFontSizeForLongestWord(
        label,
        width,
        candidates: const [7, 1],
        measureWord: fake,
      ),
      1,
      reason: 'phải bị chi phối bởi "WWW" (rộng nhất), không phải "iiiiiiii" '
          '(nhiều ký tự nhất)',
    );
  });

  test('một ký tự luôn giữ cỡ lớn nhất, bất kể font', () {
    expect(fitFontSizeForLongestWord('A', width), candidates.first);
  });

  test('từ dài hơn thì cỡ không bao giờ lớn hơn', () {
    // Không phụ thuộc font: thêm ký tự vào một từ chỉ có thể làm nó rộng ra.
    var previous = candidates.first;
    for (final label in ['A', 'AA', 'AAAA', 'AAAAAAAA', 'AAAAAAAAAAAAAAAA']) {
      final size = fitFontSizeForLongestWord(label, width);
      expect(size, lessThanOrEqualTo(previous), reason: 'ở "$label"');
      previous = size;
    }
  });

  test('đo theo từ dài nhất chứ không phải cả chuỗi', () {
    // Cùng một từ dài nhất -> cùng kết quả, dù tổng độ dài chênh nhau nhiều.
    expect(
      fitFontSizeForLongestWord('Bonbonwiese', width),
      fitFontSizeForLongestWord('a a a Bonbonwiese a a a', width),
    );
  });

  test('xuống dòng cứng cũng là ranh giới từ', () {
    // Nhãn "Bàn hôm nay" ghép hai dòng bằng '\n' (xem mode_select_screen).
    expect(
      fitFontSizeForLongestWord('Board ng\nAraw', width),
      fitFontSizeForLongestWord('Board ng Araw', width),
    );
  });

  test('không cỡ nào vừa thì lấy cỡ nhỏ nhất, không ném', () {
    expect(
      fitFontSizeForLongestWord('Donaudampfschifffahrtsgesellschaft', width),
      candidates.last,
    );
  });

  test('nhãn rỗng hoặc bề rộng 0 không làm sập', () {
    expect(fitFontSizeForLongestWord('', width), candidates.first);
    expect(fitFontSizeForLongestWord('   ', width), candidates.first);
    expect(fitFontSizeForLongestWord('Zen', 0), candidates.first);
  });
}
