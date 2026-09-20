import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/fnv1a.dart';

void main() {
  test('cùng input luôn cho cùng hash (deterministic)', () {
    expect(fnv1aHash('hello'), fnv1aHash('hello'));
    expect(fnv1aHash('seed:42:loot'), fnv1aHash('seed:42:loot'));
  });

  test('input khác nhau (kể cả rất giống nhau) cho hash khác nhau', () {
    expect(fnv1aHash('a'), isNot(fnv1aHash('b')));
    expect(fnv1aHash('seed:1:loot'), isNot(fnv1aHash('seed:2:loot')));
    expect(fnv1aHash('ab'), isNot(fnv1aHash('ba')));
  });

  test('chuỗi rỗng không throw, trả về giá trị offset-basis cố định', () {
    expect(() => fnv1aHash(''), returnsNormally);
    expect(fnv1aHash(''), fnv1aHash(''));
  });

  test('luôn trả về giá trị không âm, nằm trong phạm vi 32-bit', () {
    for (final input in ['x', 'roy_casual_kit', 'seed:99999:enemy_spawn']) {
      final h = fnv1aHash(input);
      expect(h, greaterThanOrEqualTo(0));
      expect(h, lessThanOrEqualTo(0xFFFFFFFF));
    }
  });

  test(
    'khớp đúng giá trị FNV-1a 32-bit chuẩn cho vài input đã biết trước (golden vector)',
    () {
      // Các giá trị này là hằng số FNV-1a 32-bit tiêu chuẩn, có thể tra cứu
      // độc lập — dùng để bắt lỗi nếu thuật toán vô tình bị đổi khác đi.
      expect(fnv1aHash(''), 0x811c9dc5);
      expect(fnv1aHash('a'), 0xe40c292c);
      expect(fnv1aHash('foobar'), 0xbf9cf968);
    },
  );
}
