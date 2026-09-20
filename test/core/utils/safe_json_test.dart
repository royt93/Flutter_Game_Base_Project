import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/safe_json.dart';

void main() {
  group('asIntOr', () {
    test('đúng kiểu int → trả nguyên giá trị', () {
      expect(asIntOr(5, 0), 5);
    });

    test(
      'JSON decode ra double cho số nguyên (dart:convert không phân biệt) → vẫn ra int đúng',
      () {
        expect(asIntOr(5.0, 0), 5);
      },
    );

    test('sai kiểu/null/List/Map → fallback', () {
      expect(asIntOr('5', 9), 9);
      expect(asIntOr(null, 9), 9);
      expect(asIntOr([1, 2], 9), 9);
      expect(asIntOr({'a': 1}, 9), 9);
    });

    test('BUG-22: double không hữu hạn (NaN/Infinity/-Infinity) → fallback, '
        'không throw UnsupportedError', () {
      expect(asIntOr(double.nan, 9), 9);
      expect(asIntOr(double.infinity, 9), 9);
      expect(asIntOr(double.negativeInfinity, 9), 9);
      expect(() => asIntOr(double.nan, 0), returnsNormally);
    });
  });

  group('asStringOr', () {
    test('đúng kiểu String (kể cả rỗng) → trả nguyên giá trị', () {
      expect(asStringOr('hi', 'x'), 'hi');
      expect(asStringOr('', 'x'), '');
    });

    test('sai kiểu/null → fallback', () {
      expect(asStringOr(5, 'x'), 'x');
      expect(asStringOr(null, 'x'), 'x');
      expect(asStringOr([1], 'x'), 'x');
    });
  });

  group('asDoubleOr', () {
    test('đúng kiểu double → trả nguyên giá trị', () {
      expect(asDoubleOr(1.5, 0), 1.5);
    });

    test('JSON decode ra int cho số có .0 → vẫn ra double đúng', () {
      expect(asDoubleOr(5, 0), 5.0);
    });

    test('sai kiểu/null → fallback', () {
      expect(asDoubleOr('1.5', 9), 9);
      expect(asDoubleOr(null, 9), 9);
    });
  });

  group('asBoolOr', () {
    test('đúng kiểu bool → trả nguyên giá trị', () {
      expect(asBoolOr(true, false), true);
      expect(asBoolOr(false, true), false);
    });

    test('sai kiểu/null → fallback', () {
      expect(asBoolOr('true', false), false);
      expect(asBoolOr(1, false), false);
      expect(asBoolOr(null, true), true);
    });
  });

  test('không hàm nào throw với input bất thường (List/Map lồng nhau)', () {
    expect(() => asIntOr({'x': 1}, 0), returnsNormally);
    expect(() => asStringOr([1, 2, 3], ''), returnsNormally);
    expect(() => asDoubleOr({'a': 'b'}, 0), returnsNormally);
    expect(() => asBoolOr([true], false), returnsNormally);
  });
}
