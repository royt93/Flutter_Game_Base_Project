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
}
