import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/utils/label_fit.dart';

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
    final words = label.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return candidates.first;
    final longest = words.reduce((a, b) => a.length >= b.length ? a : b);
    for (final size in candidates) {
      if (widthOf(longest, size) <= width) return size;
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
