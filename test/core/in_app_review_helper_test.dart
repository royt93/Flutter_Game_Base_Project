import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/in_app_review_helper.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `_realMs` neo vào thời điểm thật khi chạy test — mọi "mốc giờ giả lập"
/// trong file này đều là `_realMs + offsetMs`, ghi thẳng vào
/// `StorageKeys.maxMsSeen` để `nowMsClamped()` trả về đúng mốc đó mà không
/// cần chờ đồng hồ thật trôi qua (cùng pattern với energy_service_test.dart).
int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

void main() {
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  Future<void> setNowMs(int ms) => store.setInt(StorageKeys.maxMsSeen, ms);

  group('maybeRequestReview', () {
    test('streak chưa đủ ngưỡng → không hỏi, trả về false', () async {
      await setNowMs(_realMs);
      var called = false;

      final asked = await maybeRequestReview(
        recentWinStreak: 2,
        minWinStreak: 3,
        showReview: () async => called = true,
      );

      expect(asked, isFalse);
      expect(called, isFalse);
    });

    test('đủ streak, chưa từng hỏi trước đó → hỏi, trả về true', () async {
      await setNowMs(_realMs);
      var called = false;

      final asked = await maybeRequestReview(
        recentWinStreak: 3,
        minWinStreak: 3,
        showReview: () async => called = true,
      );

      expect(asked, isTrue);
      expect(called, isTrue);
    });

    test('everDeclined = true → không hỏi dù đủ streak', () async {
      await setNowMs(_realMs);
      var called = false;

      final asked = await maybeRequestReview(
        recentWinStreak: 10,
        everDeclined: true,
        showReview: () async => called = true,
      );

      expect(asked, isFalse);
      expect(called, isFalse);
    });

    test(
      'gọi lại ngay sau khi vừa hỏi (còn trong cooldown) → không hỏi lại',
      () async {
        await setNowMs(_realMs);
        var callCount = 0;

        await maybeRequestReview(
          recentWinStreak: 5,
          showReview: () async => callCount++,
        );
        // Gọi lại ngay lập tức, streak vẫn đủ điều kiện.
        final asked = await maybeRequestReview(
          recentWinStreak: 5,
          showReview: () async => callCount++,
        );

        expect(asked, isFalse);
        expect(callCount, 1);
      },
    );

    test('sau khi cooldown đã qua → hỏi lại được', () async {
      await setNowMs(_realMs);
      var callCount = 0;
      const cooldown = Duration(days: 30);

      await maybeRequestReview(
        recentWinStreak: 5,
        cooldown: cooldown,
        showReview: () async => callCount++,
      );

      await setNowMs(_realMs + cooldown.inMilliseconds + 1);
      final asked = await maybeRequestReview(
        recentWinStreak: 5,
        cooldown: cooldown,
        showReview: () async => callCount++,
      );

      expect(asked, isTrue);
      expect(callCount, 2);
    });

    test('cooldown tuỳ chỉnh ngắn hơn mặc định vẫn được tôn trọng', () async {
      await setNowMs(_realMs);
      var callCount = 0;
      const shortCooldown = Duration(minutes: 5);

      await maybeRequestReview(
        recentWinStreak: 5,
        cooldown: shortCooldown,
        showReview: () async => callCount++,
      );

      // Mới trôi qua 1 phút, chưa đủ 5 phút cooldown.
      await setNowMs(_realMs + const Duration(minutes: 1).inMilliseconds);
      final tooSoon = await maybeRequestReview(
        recentWinStreak: 5,
        cooldown: shortCooldown,
        showReview: () async => callCount++,
      );
      expect(tooSoon, isFalse);

      // Đã qua 6 phút, đủ cooldown.
      await setNowMs(_realMs + const Duration(minutes: 6).inMilliseconds);
      final okNow = await maybeRequestReview(
        recentWinStreak: 5,
        cooldown: shortCooldown,
        showReview: () async => callCount++,
      );
      expect(okNow, isTrue);
      expect(callCount, 2);
    });

    test(
      'minWinStreak tuỳ chỉnh: ngưỡng cao hơn thì streak thấp không kích hoạt',
      () async {
        await setNowMs(_realMs);
        var called = false;

        final asked = await maybeRequestReview(
          recentWinStreak: 4,
          minWinStreak: 5,
          showReview: () async => called = true,
        );

        expect(asked, isFalse);
        expect(called, isFalse);
      },
    );

    test('đồng hồ hệ thống thực tế "chậm hơn" mốc đã ghi vẫn không hỏi lại sớm '
        '(dựa vào nowMsClamped chống lùi giờ)', () async {
      // Đặt mốc đã ghi vào tương lai xa — đồng hồ thật (DateTime.now())
      // trong lúc test chạy luôn nhỏ hơn mốc này, mô phỏng đúng tình huống
      // "đã từng chỉnh đồng hồ tiến rồi chỉnh lùi lại": nowMsClamped()
      // không dùng DateTime.now() trực tiếp nên vẫn trả về >= mốc đã ghi.
      final future = _realMs + const Duration(days: 60).inMilliseconds;
      await setNowMs(future);
      var callCount = 0;

      await maybeRequestReview(
        recentWinStreak: 5,
        showReview: () async => callCount++,
      );
      // Gọi lại mà không set thêm mốc mới — nếu helper lỡ dùng
      // DateTime.now() trực tiếp thay vì nowMsClamped(), cooldown sẽ (sai)
      // tưởng đã qua vì "hiện tại" nhỏ hơn nhiều so với last-asked (future).
      final asked = await maybeRequestReview(
        recentWinStreak: 5,
        showReview: () async => callCount++,
      );

      expect(asked, isFalse);
      expect(callCount, 1);
    });

    test('BUG-25: showReview() throw → lỗi lan ra ngoài (đúng theo doc "trả '
        'về đã GỌI hay chưa", không phải đã thành công), nhưng KHÔNG tiêu '
        'cooldown — lần gọi hợp lệ tiếp theo vẫn eligible', () async {
      await setNowMs(_realMs);

      await expectLater(
        maybeRequestReview(
          recentWinStreak: 5,
          showReview: () async => throw StateError('platform lỗi tạm thời'),
        ),
        throwsStateError,
      );

      // Vẫn cùng thời điểm — nếu cooldown đã bị tiêu (bug), lần gọi này
      // sẽ bị chặn dù chưa hề hỏi thành công lần nào.
      var called = false;
      final asked2 = await maybeRequestReview(
        recentWinStreak: 5,
        showReview: () async => called = true,
      );

      expect(asked2, isTrue);
      expect(called, isTrue);
    });
  });
}
