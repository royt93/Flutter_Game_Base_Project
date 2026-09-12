import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/daily_login_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `_realDay` neo vào ngày thật tại thời điểm chạy test — mọi "ngày giả lập"
/// trong file này đều là `_realDay + offset` (offset >= 0), ghi thẳng vào
/// `StorageKeys.maxEpochDaySeen`. `todayEpochDayClamped()` trả về
/// max(ngày thật, mốc đã ghi), nên với offset >= 0 giá trị trả về luôn đúng
/// bằng mốc đã set — mô phỏng "N ngày sau" mà không cần chờ đồng hồ thật,
/// và không phụ thuộc giờ thực khi chạy test (không có mép nửa đêm).
int get _realDay => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

void main() {
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  Future<void> setDay(int day) => store.setInt(StorageKeys.maxEpochDaySeen, day);

  group('DailyLoginService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(DailyLoginService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = DailyLoginService();
      Get.put(service, permanent: true);
      expect(DailyLoginService.maybe, same(service));
    });

    test('trước khi claim lần nào: canClaimToday true, streak = 0', () async {
      await setDay(_realDay);
      final service = DailyLoginService();

      expect(service.canClaimToday(), isTrue);
      expect(service.currentStreakDay, 0);
      expect(service.claimedDaysInCycle, isEmpty);
    });

    test('claim lần đầu → streak = 1, ngày 1 được đánh dấu claimed', () async {
      await setDay(_realDay);
      final service = DailyLoginService();

      final result = service.claimToday();

      expect(result.streakDay, 1);
      expect(service.currentStreakDay, 1);
      expect(service.claimedDaysInCycle, {1});
    });

    test('claim 2 lần trong cùng 1 ngày → lần 2 không đổi gì (đã claim)', () async {
      await setDay(_realDay);
      final service = DailyLoginService();

      service.claimToday();
      final second = service.claimToday();

      expect(second.streakDay, 1);
      expect(second.streakWasReset, isFalse);
      expect(service.currentStreakDay, 1);
    });

    test('claim rồi → canClaimToday() trả về false trong cùng ngày đó', () async {
      await setDay(_realDay);
      final service = DailyLoginService();

      service.claimToday();

      expect(service.canClaimToday(), isFalse);
    });

    test('claim 3 ngày liên tiếp → streak tăng dần 1, 2, 3', () async {
      final service = DailyLoginService();

      await setDay(_realDay);
      expect(service.claimToday().streakDay, 1);

      await setDay(_realDay + 1);
      expect(service.claimToday().streakDay, 2);

      await setDay(_realDay + 2);
      expect(service.claimToday().streakDay, 3);

      expect(service.claimedDaysInCycle, {1, 2, 3});
    });

    test('claim đủ 7 ngày liên tiếp rồi ngày thứ 8 → quay vòng về ngày 1, '
        'danh sách claimed của chu kỳ mới được xoá sạch', () async {
      final service = DailyLoginService();

      for (var i = 0; i < 7; i++) {
        await setDay(_realDay + i);
        service.claimToday();
      }
      expect(service.currentStreakDay, 7);
      expect(service.claimedDaysInCycle, {1, 2, 3, 4, 5, 6, 7});

      await setDay(_realDay + 7);
      final result = service.claimToday();

      expect(result.streakDay, 1);
      expect(result.streakWasReset, isFalse, reason: 'quay vòng đủ chu kỳ, không phải bỏ lỡ ngày');
      expect(service.claimedDaysInCycle, {1});
    });

    test('bỏ lỡ 1 ngày (claim cách nhau 2 ngày) → streak reset về ngày 1', () async {
      final service = DailyLoginService();

      await setDay(_realDay);
      service.claimToday();
      await setDay(_realDay + 1);
      service.claimToday();
      expect(service.currentStreakDay, 2);

      // Bỏ lỡ ngày _realDay + 2, claim tiếp ở _realDay + 3.
      await setDay(_realDay + 3);
      final result = service.claimToday();

      expect(result.streakDay, 1);
      expect(result.streakWasReset, isTrue);
      expect(service.claimedDaysInCycle, {1});
    });

    test(
      'chỉnh lùi giờ máy: mốc ClampedClock đã ghi ngày tương lai thì gọi lại '
      'sau đó vẫn thấy đúng ngày đó, không claim lại được',
      () async {
        // Service không gọi DateTime.now() trực tiếp — chỉ dựa vào
        // todayEpochDayClamped(), vốn tự chống chỉnh lùi (test riêng ở
        // clamped_clock_test.dart: mốc max không bao giờ giảm). Ở đây chỉ
        // cần xác nhận service tôn trọng đúng mốc đó: "vặn đồng hồ tiến rồi
        // claim, vặn lùi lại" — mốc đã ghi vẫn giữ nguyên nên lần claim thứ 2
        // vẫn thấy "hôm nay" là ngày tương lai đã claim, không được claim
        // thêm hay reset streak.
        final future = _realDay + 30;
        await setDay(future);
        final service = DailyLoginService();
        final first = service.claimToday();
        expect(first.streakDay, 1);

        final second = service.claimToday();
        expect(second.streakDay, 1);
        expect(second.streakWasReset, isFalse);
      },
    );

    test('persist qua "restart": tạo service mới đọc lại đúng streak đã lưu', () async {
      final service = DailyLoginService();
      await setDay(_realDay);
      service.claimToday();
      await setDay(_realDay + 1);
      service.claimToday();

      final restarted = DailyLoginService();
      expect(restarted.currentStreakDay, 2);
      expect(restarted.claimedDaysInCycle, {1, 2});
      expect(restarted.canClaimToday(), isFalse);
    });

    group('BUG-18: save race khi claimToday() gọi rất nhanh liên tiếp', () {
      test(
        'nhiều ngày claim liên tiếp không chờ save trước hoàn tất → sau khi '
        'mọi save settle, streak persist đúng qua instance mới (không bị 1 '
        'write cũ ghi đè bằng snapshot lỗi thời)',
        () async {
          final service = DailyLoginService();

          // Khác các test khác ở trên (luôn có `await setDay(...)` xen giữa,
          // đủ thời gian cho save trước settle) — ở đây đổi ngày và claim
          // LIÊN TIẾP không await gì cả, đúng kịch bản "nhiều claim dồn dập"
          // mô tả trong Hiện trạng.
          await setDay(_realDay);
          service.claimToday();
          unawaited(setDay(_realDay + 1));
          service.claimToday();
          unawaited(setDay(_realDay + 2));
          service.claimToday();

          await service.debugPendingSaves;

          final restarted = DailyLoginService();
          expect(restarted.currentStreakDay, 3);
          expect(restarted.claimedDaysInCycle, {1, 2, 3});
        },
      );
    });
  });
}
