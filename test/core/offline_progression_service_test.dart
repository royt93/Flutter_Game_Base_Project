import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/offline_progression_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
import 'package:roy_casual_kit/core/utils/trusted_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Get.reset() does NOT remove permanent:true registrations — a stale
  // StorageService/OfflineProgressionService from an earlier test would
  // keep serving nowMsClamped()'s reads/writes, leaking real timestamps
  // across tests despite each test's own fresh mock SharedPreferences.
  tearDown(() => Get.deleteAll(force: true));

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  /// Giả lập "đã đi vắng [hours] giờ" bằng cách đẩy mốc kẹp đồng hồ
  /// (`StorageKeys.maxMsSeen`, thứ `nowMsClamped()` đọc/kẹp vào) tiến lên
  /// thẳng — không cần chờ đồng hồ thật trôi qua.
  Future<void> advanceHours(double hours) async {
    final current = store.getInt(StorageKeys.maxMsSeen);
    await store.setInt(
      StorageKeys.maxMsSeen,
      current + (hours * 3600000).round(),
    );
  }

  group('OfflineProgressionService', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(OfflineProgressionService.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);
      expect(OfflineProgressionService.maybe, same(service));
    });

    test('chưa từng claim -> pendingEarnings = 0 (không tự ăn free)', () {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);

      expect(service.pendingEarnings(10), 0.0);
    });

    test(
      'BUG: claim() lần đầu tiên không được lấy đồng hồ thật 2 lần khác nhau '
      '(offlineLastClaimedMs phải khớp đúng maxMsSeen sau khi claim xong)',
      () async {
        final service = OfflineProgressionService();
        Get.put(service, permanent: true);

        await service.claim(5); // lần claim đầu tiên, chưa từng có mốc cũ

        // claim() nội bộ nếu lấy nowMsClamped() 2 lần khác nhau cho cùng 1
        // mốc "bây giờ" (1 lần trực tiếp, 1 lần qua fallback của
        // _lastClaimedMs khi chưa từng claim) thì 2 giá trị này sẽ lệch
        // nhau đúng bằng khoảng thời gian thực trôi qua giữa 2 lần đọc —
        // baked vĩnh viễn vào earnings của mọi claim sau đó.
        expect(
          store.getInt(StorageKeys.offlineLastClaimedMs),
          store.getInt(StorageKeys.maxMsSeen),
        );
      },
    );

    test(
      'round-trip: đặt tốc độ, giả lập thời gian trôi, verify đúng số',
      () async {
        final service = OfflineProgressionService(
          maxOfflineCap: const Duration(hours: 8),
        );
        Get.put(service, permanent: true);

        // Baseline: claim ngay để chốt mốc "lần cuối claim" = bây giờ.
        final first = await service.claim(5);
        expect(first, 0.0);

        // Giả lập đi vắng 2 giờ, tốc độ 5/giây.
        await advanceHours(2);
        final earned = service.pendingEarnings(5);
        expect(earned, 2 * 3600 * 5);
      },
    );

    test(
      'vượt maxOfflineCap -> thu nhập bị giới hạn đúng cap, không tính vượt',
      () async {
        final service = OfflineProgressionService(
          maxOfflineCap: const Duration(hours: 8),
        );
        Get.put(service, permanent: true);

        await service.claim(2); // chốt mốc

        // Đi vắng 3 ngày (72 giờ) — vượt xa cap 8 giờ.
        await advanceHours(72);
        final earned = service.pendingEarnings(2);

        expect(
          earned,
          8 * 3600 * 2,
          reason: 'chỉ tính tối đa 8 giờ, không tính 72 giờ thật',
        );
      },
    );

    test(
      'pendingEarnings không mutate trạng thái (gọi nhiều lần ra cùng kết quả)',
      () async {
        final service = OfflineProgressionService();
        Get.put(service, permanent: true);

        await service.claim(3);
        await advanceHours(1);

        final a = service.pendingEarnings(3);
        final b = service.pendingEarnings(3);
        expect(a, b);
      },
    );

    test(
      'claim() trả về đúng số đã tích luỹ VÀ reset mốc lastClaimed về hiện tại',
      () async {
        final service = OfflineProgressionService();
        Get.put(service, permanent: true);

        await service.claim(4); // chốt mốc ban đầu
        await advanceHours(1);

        final earned = await service.claim(4);
        expect(earned, 1 * 3600 * 4);

        // Ngay sau khi claim, gần như không còn gì để nhận nữa — không đúng
        // 0.0 tuyệt đối vì thời gian thực vẫn trôi 1 chút giữa claim() và
        // pendingEarnings() (2 lệnh gọi async riêng biệt), nhưng phải rất nhỏ.
        expect(service.pendingEarnings(4), closeTo(0.0, 0.5));
      },
    );

    test(
      'claim() persist mốc lastClaimed qua StorageKeys (sống sót qua restart)',
      () async {
        final service = OfflineProgressionService();
        Get.put(service, permanent: true);

        await advanceHours(1);
        final before = nowMsClamped();
        await service.claim(1);

        // "Restart": tạo instance service mới, đọc lại từ storage.
        final restarted = OfflineProgressionService();
        // Không đúng 0.0 tuyệt đối — cùng lý do ở test claim() ngay phía
        // trên: thời gian thực trôi 1 chút giữa claim() và pendingEarnings().
        expect(restarted.pendingEarnings(1), closeTo(0.0, 0.5));
        expect(
          store.getInt(StorageKeys.offlineLastClaimedMs),
          greaterThanOrEqualTo(before),
        );
      },
    );

    test('cap mặc định khi không truyền vào constructor', () async {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);

      await service.claim(1);
      await advanceHours(
        1000,
      ); // rất xa, chắc chắn vượt bất kỳ cap mặc định nào

      final earned = service.pendingEarnings(1);
      expect(earned, service.maxOfflineCap.inSeconds * 1);
    });

    group('BUG-27: validate tham số kinh tế không hợp lệ', () {
      test('maxOfflineCap âm → ArgumentError thay vì throw mơ hồ từ clamp', () {
        final service = OfflineProgressionService(
          maxOfflineCap: const Duration(seconds: -1),
        );
        Get.put(service, permanent: true);

        expect(() => service.pendingEarnings(1), throwsArgumentError);
      });

      test('productionRatePerSecond âm → ArgumentError', () {
        final service = OfflineProgressionService();
        Get.put(service, permanent: true);

        expect(() => service.pendingEarnings(-1), throwsArgumentError);
      });

      test('productionRatePerSecond NaN/Infinity → ArgumentError', () {
        final service = OfflineProgressionService();
        Get.put(service, permanent: true);

        expect(() => service.pendingEarnings(double.nan), throwsArgumentError);
        expect(
          () => service.pendingEarnings(double.infinity),
          throwsArgumentError,
        );
      });

      test('claim() với tham số không hợp lệ ném lỗi trước, KHÔNG advance '
          'offlineLastClaimedMs', () async {
        final service = OfflineProgressionService();
        Get.put(service, permanent: true);
        await service.claim(1);
        final before = store.getInt(StorageKeys.offlineLastClaimedMs);

        await expectLater(service.claim(-5), throwsArgumentError);

        expect(store.getInt(StorageKeys.offlineLastClaimedMs), before);
      });
    });
  });

  group('ENH-86: trustedClock optional (mặc định null, không đổi hành vi)', () {
    test('không truyền trustedClock -> claim vẫn dùng nowMsClamped như cũ', () async {
      final service = OfflineProgressionService();
      Get.put(service, permanent: true);
      expect(service.trustedClock, isNull);

      await service.claim(10);
      await advanceHours(2);
      final earned = await service.claim(10);

      expect(earned, closeTo(2 * 3600 * 10, 0.01));
    });

    test(
      'có trustedClock, đồng hồ trôi bình thường -> claim tính đúng như '
      'nowMsClamped (không đổi kết quả hợp lệ)',
      () async {
        // Baseline khởi tạo khác 0 — `_lastClaimedMsOr` coi mốc 0 đã lưu
        // là "chưa từng claim" (hành vi có sẵn, không thuộc ENH-86), nên
        // test dùng mốc khác 0 để tránh nhầm với case đó.
        var wallMs = 1000000;
        var monotonicMs = 0;
        final trustedClock = TrustedClockService(
          sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
        );
        final service = OfflineProgressionService(trustedClock: trustedClock);
        Get.put(service, permanent: true);

        // Sample đầu tiên: chỉ khởi tạo baseline + offlineLastClaimedMs.
        await service.claim(10);

        // 2 giờ trôi qua bình thường (wall và monotonic cùng tiến).
        const twoHoursMs = 2 * 3600 * 1000;
        wallMs += twoHoursMs;
        monotonicMs += twoHoursMs;

        final earned = await service.claim(10);

        expect(earned, closeTo(2 * 3600 * 10, 0.01));
        expect(trustedClock.lastJudgement, ClockJudgement.normal);
      },
    );

    test(
      'suspiciousForwardJump (vặn đồng hồ tới tương lai rồi claim) bị từ '
      'chối: earned = 0, không phải earned lớn như nowMsClamped sẽ cho',
      () async {
        var wallMs = 1000000;
        var monotonicMs = 0;
        final trustedClock = TrustedClockService(
          sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
        );
        final service = OfflineProgressionService(trustedClock: trustedClock);
        Get.put(service, permanent: true);

        // Khởi tạo baseline hợp lệ tại mốc 1000000.
        await service.claim(10);

        // Vặn wall tới +1 năm, monotonic chỉ tiến 1 giây thật (nhảy vọt
        // nghi vấn) — nếu dùng nowMsClamped, claim() sẽ trả về gần 1 năm
        // tiền thưởng (bị cap ở maxOfflineCap) ngay lập tức.
        const oneYearMs = 365 * 24 * 3600 * 1000;
        wallMs += oneYearMs;
        monotonicMs += 1000;

        final earned = await service.claim(10);

        expect(earned, 0.0);
        expect(trustedClock.lastJudgement, ClockJudgement.suspiciousForwardJump);
      },
    );

    test(
      'rewind (vặn đồng hồ lùi rồi claim) cũng bị từ chối: earned = 0',
      () async {
        var wallMs = 100000;
        var monotonicMs = 0;
        final trustedClock = TrustedClockService(
          sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
        );
        final service = OfflineProgressionService(trustedClock: trustedClock);
        Get.put(service, permanent: true);

        await service.claim(10);

        // Vặn wall lùi hẳn về trước (vượt tolerance mặc định 5 giây),
        // monotonic vẫn tiến bình thường theo tiến trình thật.
        wallMs = 0;
        monotonicMs += 1000;

        final earned = await service.claim(10);

        expect(earned, 0.0);
        expect(trustedClock.lastJudgement, ClockJudgement.rewind);
      },
    );

    test(
      'phục hồi sau suspiciousForwardJump: sample bình thường tiếp theo '
      'không bị khoá vĩnh viễn (khác nowMsClamped)',
      () async {
        var wallMs = 1000000;
        var monotonicMs = 0;
        final trustedClock = TrustedClockService(
          sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
        );
        final service = OfflineProgressionService(trustedClock: trustedClock);
        Get.put(service, permanent: true);

        await service.claim(10);

        const oneYearMs = 365 * 24 * 3600 * 1000;
        wallMs += oneYearMs;
        monotonicMs += 1000;
        await service.claim(10); // bị từ chối, baseline không đổi

        // Đồng hồ được sửa lại về đúng thời điểm thật, tiếp tục trôi bình
        // thường từ baseline cũ (1000000ms, mốc "previous" bị đóng băng từ
        // trước khi nhảy vọt) thêm 1 giờ thật.
        wallMs = 1000000 + 3600 * 1000;
        monotonicMs += 3600 * 1000;

        final earned = await service.claim(10);

        expect(trustedClock.lastJudgement, ClockJudgement.normal);
        expect(earned, closeTo(3600 * 10, 0.01));
      },
    );
  });
}
