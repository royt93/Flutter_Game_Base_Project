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

  test('web and native agree: vectors computed with exact big integers', () {
    // Expected values come from an arbitrary-precision reference. A product
    // like `hash * prime` passes 2^53 here, so a naive implementation matches
    // on the VM but rounds differently on the web (run with
    // `flutter test --platform chrome` to cover that side).
    const vectors = <(String, int)>[
      ('seed', 1346747564),
      ('loot', 3790556855),
      ('level', 2610554845),
      ('ab', 1294271946),
      ('anon', 2832133407),
      ('exp', 1923516200),
      ('périod', 2400031401),
      ('日本語', 2153733351),
      ('🙂', 1470331467),
      ('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 2226015845),
      ('playerId_123456789', 3919279805),
      ('periodKey:2026-11-23:daily', 2977589605),
      ('H丵k ', 1157853809),
      (',举串中三严丒丯[S', 218770669),
      ('举両hi不丒丏丼丳丽丙B为丙', 4064265681),
      ('主丄H両丶丢O丒!Y?丢一u东丐*丧QPQL丼', 384923881),
      ('丹丿i业丫lf9丆丘{r丗丶丱7主两丩丏,下', 1878674024),
      ('J#Mo严u丌5M丨丈且@丠!丂丌HS主丏', 3316823768),
      ('丠E~个丏Ueg4丐l丐丱>0串2丣両1丄Kt\\专z丣丯', 422905544),
      ('为v4一bq丯1丛丅P丒両%严', 741688051),
      ('1丁V|H#丈Fl丩三A', 3009577111),
      ('\\丟为*丧t丷丿H东临专', 502175272),
      ('丐B丢丒=丏为丂临,中\'丢个丽!丏I丣*专<丕*', 2325389408),
      ('丢%丫丨', 1466562655),
    ];
    for (final (input, expected) in vectors) {
      expect(fnv1aHash(input), expected, reason: 'input: $input');
    }
  });
}
