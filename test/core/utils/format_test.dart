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

  group('fmtDurLong', () {
    test('dưới 1 giờ → giống fmtDur (mm:ss)', () {
      expect(fmtDurLong(const Duration(seconds: 5)), '00:05');
      expect(fmtDurLong(const Duration(minutes: 45, seconds: 9)), '45:09');
    });

    test('từ 1 giờ trở lên → hh:mm:ss', () {
      expect(fmtDurLong(const Duration(hours: 1, minutes: 15)), '01:15:00');
      expect(
        fmtDurLong(const Duration(hours: 26, minutes: 5, seconds: 3)),
        '26:05:03',
      );
    });
  });

  group('fmtNumCompact', () {
    test('dưới 1000 → giống fmtNum, không rút gọn', () {
      expect(fmtNumCompact(0), '0');
      expect(fmtNumCompact(999), '999');
      expect(fmtNumCompact(-500), '-500');
    });

    test('hàng nghìn/triệu/tỷ rút gọn K/M/B, bỏ .0 thừa', () {
      expect(fmtNumCompact(1000), '1K');
      expect(fmtNumCompact(1500), '1.5K');
      expect(fmtNumCompact(999000), '999K');
      expect(fmtNumCompact(1000000), '1M');
      expect(fmtNumCompact(12345678), '12.3M');
      expect(fmtNumCompact(1000000000), '1B');
      expect(fmtNumCompact(-1500), '-1.5K');
    });

    test('hàng nghìn tỷ (T)', () {
      expect(fmtNumCompact(1000000000000), '1T');
    });
  });
}
