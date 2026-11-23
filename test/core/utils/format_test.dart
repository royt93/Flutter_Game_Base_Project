import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
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

  group('fmtNum fallback (catch block)', () {
    test('ném lỗi -> rơi về format fallback kiểu tiếng Việt', () {
      final old = Get.locale;
      addTearDown(() => Get.updateLocale(old ?? const Locale('en')));
      // 'xx_XX' không có data trong intl, NumberFormat sẽ throw
      Get.updateLocale(const Locale('xx_XX'));

      expect(fmtNum(0), '0');
      expect(fmtNum(999), '999');
      expect(fmtNum(1000), '1.000');
      expect(fmtNum(1234567), '1.234.567');
      expect(fmtNum(-1234567), '-1.234.567');
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

  group('fmtDurDays (FEAT-130)', () {
    test('dưới 24 giờ → uỷ quyền cho fmtDurLong', () {
      expect(fmtDurDays(const Duration(seconds: 5)), '00:05');
      expect(fmtDurDays(const Duration(minutes: 45, seconds: 9)), '45:09');
      expect(fmtDurDays(const Duration(hours: 1, minutes: 15)), '01:15:00');
      expect(
        fmtDurDays(const Duration(hours: 23, minutes: 59, seconds: 59)),
        '23:59:59',
      );
    });

    test('từ 24 giờ trở lên → định dạng Xd Yh', () {
      expect(fmtDurDays(const Duration(days: 1)), '1d 0h');
      expect(
        fmtDurDays(const Duration(days: 3, hours: 4, minutes: 20)),
        '3d 4h',
      );
      expect(fmtDurDays(const Duration(hours: 50, minutes: 12)), '2d 2h');
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

  group('fmtRelative (FEAT-232)', () {
    final now = DateTime.utc(2026, 11, 23, 12);
    String at(Duration ago) => fmtRelative(now.subtract(ago), now: now);

    void useLocale(String code) {
      Get.clearTranslations();
      Get.addTranslations(AppTranslations().keys);
      final old = Get.locale;
      Get.updateLocale(Locale(code));
      addTearDown(() => Get.updateLocale(old ?? const Locale('en')));
    }

    tearDown(Get.clearTranslations);

    test('en: every bucket boundary', () {
      useLocale('en');
      expect(at(Duration.zero), 'Just now');
      expect(at(const Duration(seconds: 59)), 'Just now');
      expect(at(const Duration(seconds: 60)), '1 minute ago');
      expect(at(const Duration(seconds: 119)), '1 minute ago');
      expect(at(const Duration(minutes: 2)), '2 minutes ago');
      expect(at(const Duration(minutes: 59, seconds: 59)), '59 minutes ago');
      expect(at(const Duration(minutes: 60)), '1 hour ago');
      expect(at(const Duration(hours: 2)), '2 hours ago');
      expect(at(const Duration(hours: 23, minutes: 59)), '23 hours ago');
      expect(at(const Duration(hours: 24)), 'Yesterday');
      expect(at(const Duration(hours: 47, minutes: 59)), 'Yesterday');
      expect(at(const Duration(hours: 48)), '2 days ago');
      expect(at(const Duration(days: 30)), '30 days ago');
    });

    test('vi: same buckets in Vietnamese', () {
      useLocale('vi');
      expect(at(const Duration(seconds: 30)), 'Vừa xong');
      expect(at(const Duration(minutes: 1)), '1 phút trước');
      expect(at(const Duration(minutes: 5)), '5 phút trước');
      expect(at(const Duration(hours: 1)), '1 giờ trước');
      expect(at(const Duration(hours: 5)), '5 giờ trước');
      expect(at(const Duration(hours: 30)), 'Hôm qua');
      expect(at(const Duration(days: 3)), '3 ngày trước');
    });

    test('a future time (clock skew) reads as just now, never throws', () {
      useLocale('en');
      expect(
        fmtRelative(now.add(const Duration(hours: 5)), now: now),
        'Just now',
      );
    });

    test('a very old time does not throw and counts whole days', () {
      useLocale('en');
      expect(at(const Duration(days: 36500)), '36500 days ago');
    });

    test('elapsed-time buckets ignore the time zone and DST', () {
      useLocale('en');
      final then = DateTime(2026, 3, 8, 12);
      final later = then.add(const Duration(hours: 25));
      expect(fmtRelative(then, now: later), 'Yesterday');
    });
  });
}
