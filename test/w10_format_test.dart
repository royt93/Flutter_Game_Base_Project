import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/utils/format.dart';

void main() {
  tearDown(Get.reset);

  group('Wave 10 — fmtNum (định dạng xu/điểm)', () {
    test('số < 1000 giữ nguyên', () {
      expect(fmtNum(0), '0');
      expect(fmtNum(50), '50');
      expect(fmtNum(999), '999');
    });

    test('locale vi → phân tách bằng dấu chấm', () {
      Get.locale = const Locale('vi', 'VN');
      expect(fmtNum(10000), '10.000');
      expect(fmtNum(1220), '1.220');
      expect(fmtNum(2000000000), '2.000.000.000');
    });

    test('locale en → phân tách bằng dấu phẩy', () {
      Get.locale = const Locale('en', 'US');
      expect(fmtNum(10000), '10,000');
      expect(fmtNum(1234567), '1,234,567');
    });

    test('số âm vẫn nhóm đúng', () {
      Get.locale = const Locale('vi', 'VN');
      expect(fmtNum(-12345), '-12.345');
    });

    test('locale null (chưa set) không ném lỗi', () {
      Get.reset(); // Get.locale = null
      expect(() => fmtNum(10000), returnsNormally);
    });
  });

  group(
    'Wave 14 fix — durationToLocalMidnight (countdown không lệch múi giờ)',
    () {
      test('ngày cuối tuần giải: tới nửa đêm GIỜ MÁY, không lệch UTC', () {
        // 10:00 sáng giờ máy, daysLeft=1 (đang ngày chót) → nửa đêm tối nay = 14h.
        // Trước fix: tái dựng UTC midnight → ở UTC+7 sẽ ra 7h (lệch -7h) hoặc 0.
        final now = DateTime(2026, 6, 19, 10, 0);
        expect(durationToLocalMidnight(now, 1), const Duration(hours: 14));
      });

      test('còn nhiều ngày: cộng đúng số ngày tới nửa đêm', () {
        final now = DateTime(2026, 6, 19, 22, 30);
        // còn 3 ngày → nửa đêm 2026-06-22 = 1 giờ 30 phút + 2 ngày.
        expect(
          durationToLocalMidnight(now, 3),
          const Duration(days: 2, hours: 1, minutes: 30),
        );
      });

      test('daysLeft tràn cuối tháng được chuẩn hoá', () {
        final now = DateTime(2026, 6, 30, 12, 0);
        // còn 1 ngày → nửa đêm 2026-07-01 (Dart tự chuyển tháng) = 12 giờ.
        expect(durationToLocalMidnight(now, 1), const Duration(hours: 12));
      });

      test('đã qua mốc (daysLeft 0, đang nửa đêm) → Duration.zero', () {
        final now = DateTime(2026, 6, 19, 0, 0);
        expect(durationToLocalMidnight(now, 0), Duration.zero);
      });
    },
  );

  // Audit gap: fmtDur (đếm ngược hồi mạng Home/Level Select/World Map) chưa
  // có test biên nào trước bản vá này. Khoá hành vi hiện tại, kể cả quirk
  // >=1 giờ bị wrap về 00 (remainder(60)) — hàm chỉ dùng cho countdown hồi
  // mạng thường <1 giờ nên chưa cần sửa, nhưng phải biết nếu ai đó đổi.
  group('Wave 10 — fmtDur (mm:ss, đếm ngược hồi mạng)', () {
    test('biên dưới: 0s, 9s (đệm 0), 59s', () {
      expect(fmtDur(Duration.zero), '00:00');
      expect(fmtDur(const Duration(seconds: 9)), '00:09');
      expect(fmtDur(const Duration(seconds: 59)), '00:59');
    });

    test('tràn phút: 60s → 01:00, 61s → 01:01', () {
      expect(fmtDur(const Duration(seconds: 60)), '01:00');
      expect(fmtDur(const Duration(seconds: 61)), '01:01');
    });

    test('gần 1 giờ: 3599s → 59:59', () {
      expect(fmtDur(const Duration(seconds: 3599)), '59:59');
    });

    test(
      'quirk hiện tại: >=1 giờ bị wrap về 00 (remainder 60) — KHÔNG phải bug '
      'mới, chỉ khoá hành vi hiện có vì hàm chỉ dùng cho countdown <1 giờ',
      () {
        expect(fmtDur(const Duration(seconds: 3600)), '00:00');
        // 65 phút = 1h5' → inMinutes.remainder(60)=5, inSeconds.remainder(60)=0
        expect(fmtDur(const Duration(hours: 1, minutes: 5)), '05:00');
      },
    );
  });
}
