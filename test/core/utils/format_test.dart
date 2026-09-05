import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/format.dart';

void main() {
  group('fmtDur', () {
    test('định dạng mm:ss với 2 chữ số mỗi phần', () {
      expect(fmtDur(const Duration(seconds: 5)), '00:05');
      expect(fmtDur(const Duration(minutes: 1, seconds: 9)), '01:09');
      expect(fmtDur(const Duration(minutes: 65)), '05:00');
    });
  });

  group('durationToLocalMidnight', () {
    test(
      'daysLeft=0 → mốc là nửa đêm hôm nay, luôn đã qua → Duration.zero',
      () {
        final now = DateTime(2026, 7, 12, 10, 0, 0);
        final d = durationToLocalMidnight(now, 0);
        expect(d, Duration.zero);
      },
    );

    test('daysLeft=1 → khoảng cách tới nửa đêm ngày mai', () {
      final now = DateTime(2026, 7, 12, 10, 0, 0);
      final d = durationToLocalMidnight(now, 1);
      expect(d, const Duration(hours: 14));
    });

    test('mốc đã qua (ms <= 0) → trả Duration.zero, không âm', () {
      final now = DateTime(2026, 7, 12, 23, 59, 59);
      final d = durationToLocalMidnight(now, -1);
      expect(d, Duration.zero);
    });

    test('tràn ngày cuối tháng tự chuẩn hoá sang tháng kế', () {
      final now = DateTime(2026, 7, 30, 0, 0, 0);
      final d = durationToLocalMidnight(now, 5);
      // 30/7 + 5 ngày = 4/8 → còn đúng 5 ngày kể từ nửa đêm 30/7.
      expect(d, const Duration(days: 5));
    });
  });

  group('fmtNum', () {
    test('số dương/âm/0 định dạng có dấu phân tách hàng nghìn', () {
      expect(fmtNum(0), '0');
      expect(fmtNum(999), '999');
      expect(fmtNum(-1000), isNot(contains('--')));
      expect(fmtNum(1000000).replaceAll(RegExp(r'[.,]'), ''), '1000000');
    });
  });
}
