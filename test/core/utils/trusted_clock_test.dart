import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/trusted_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTrustedTimeSource implements TrustedTimeSource {
  _FakeTrustedTimeSource(this.value);
  int? value;

  @override
  Future<int?> fetchTrustedNowMs() async => value;
}

void main() {
  group('classifyClockSample (pure)', () {
    test('wall delta ~ monotonic delta (bình thường trôi qua) -> normal', () {
      final result = classifyClockSample(
        previous: const ClockSample(wallMs: 0, monotonicMs: 0),
        current: const ClockSample(wallMs: 10000, monotonicMs: 10000),
      );
      expect(result, ClockJudgement.normal);
    });

    test(
      'elapsed dài (offline 3 ngày) nhưng cả 2 delta khớp nhau -> normal',
      () {
        const threeDaysMs = 3 * 24 * 60 * 60 * 1000;
        final result = classifyClockSample(
          previous: const ClockSample(wallMs: 0, monotonicMs: 0),
          current: const ClockSample(
            wallMs: threeDaysMs,
            monotonicMs: threeDaysMs,
          ),
        );
        expect(result, ClockJudgement.normal);
      },
    );

    test('wall lùi lại rõ rệt (vượt tolerance) -> rewind', () {
      final result = classifyClockSample(
        previous: const ClockSample(wallMs: 100000, monotonicMs: 0),
        current: const ClockSample(wallMs: 0, monotonicMs: 1000),
      );
      expect(result, ClockJudgement.rewind);
    });

    test('wall lùi nhẹ trong tolerance (NTP hiệu chỉnh nhỏ) -> vẫn normal', () {
      final result = classifyClockSample(
        previous: const ClockSample(wallMs: 10000, monotonicMs: 0),
        current: const ClockSample(wallMs: 9000, monotonicMs: 1000),
        normalTolerance: const Duration(seconds: 5),
      );
      expect(result, ClockJudgement.normal);
    });

    test(
      'wall nhảy vọt tới tương lai trong khi monotonic gần như không đổi -> suspiciousForwardJump',
      () {
        const oneYearMs = 365 * 24 * 60 * 60 * 1000;
        final result = classifyClockSample(
          previous: const ClockSample(wallMs: 0, monotonicMs: 0),
          current: const ClockSample(wallMs: oneYearMs, monotonicMs: 500),
        );
        expect(result, ClockJudgement.suspiciousForwardJump);
      },
    );

    test(
      'drift đúng bằng ngưỡng thì vẫn normal, vượt ngưỡng 1ms mới suspicious',
      () {
        const threshold = Duration(hours: 1);
        final atThreshold = classifyClockSample(
          previous: const ClockSample(wallMs: 0, monotonicMs: 0),
          current: ClockSample(
            wallMs: threshold.inMilliseconds,
            monotonicMs: 0,
          ),
          suspiciousJumpThreshold: threshold,
        );
        expect(atThreshold, ClockJudgement.normal);

        final overThreshold = classifyClockSample(
          previous: const ClockSample(wallMs: 0, monotonicMs: 0),
          current: ClockSample(
            wallMs: threshold.inMilliseconds + 1,
            monotonicMs: 0,
          ),
          suspiciousJumpThreshold: threshold,
        );
        expect(overThreshold, ClockJudgement.suspiciousForwardJump);
      },
    );

    test(
      'monotonic lùi lại (process mới khởi động) -> reboot, bất kể wall delta',
      () {
        final result = classifyClockSample(
          previous: const ClockSample(wallMs: 999999, monotonicMs: 500000),
          current: const ClockSample(wallMs: 1000000, monotonicMs: 10),
        );
        expect(result, ClockJudgement.reboot);
      },
    );
  });

  group('TrustedClockService: hydrate/migrate lần đầu', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      Get.put(storage, permanent: true);
    });
    tearDown(Get.reset);

    test(
      'chưa từng có gì lưu trước đó: baseline = wall time của sample đầu',
      () {
        final service = TrustedClockService(
          sampleNow: () => const ClockSample(wallMs: 5000, monotonicMs: 0),
        );

        expect(service.nowMsTrusted(), 5000);
      },
    );

    test(
      'migrate từ legacy StorageKeys.maxMsSeen khi nó CAO HƠN wall time hiện tại',
      () async {
        await StorageService.to.setInt(StorageKeys.maxMsSeen, 999999);
        final service = TrustedClockService(
          sampleNow: () => const ClockSample(wallMs: 5000, monotonicMs: 0),
        );

        expect(service.nowMsTrusted(), 999999);
      },
    );

    test(
      'KHÔNG dùng legacy watermark khi nó THẤP HƠN wall time hiện tại (đã lỗi thời)',
      () async {
        await StorageService.to.setInt(StorageKeys.maxMsSeen, 100);
        final service = TrustedClockService(
          sampleNow: () => const ClockSample(wallMs: 5000, monotonicMs: 0),
        );

        expect(service.nowMsTrusted(), 5000);
      },
    );
  });

  group('TrustedClockService: chống rewind (không regression)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      Get.put(storage, permanent: true);
    });
    tearDown(Get.reset);

    test('gọi lặp lại với thời gian trôi bình thường: baseline tăng đúng', () {
      var wallMs = 0;
      var monotonicMs = 0;
      final service = TrustedClockService(
        sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
      );

      expect(service.nowMsTrusted(), 0);
      wallMs = 10000;
      monotonicMs = 10000;
      expect(service.nowMsTrusted(), 10000);
      wallMs = 20000;
      monotonicMs = 20000;
      expect(service.nowMsTrusted(), 20000);
    });

    test('vặn đồng hồ lùi: baseline KHÔNG lùi theo, giữ nguyên giá trị cũ', () {
      var wallMs = 100000;
      var monotonicMs = 0;
      final service = TrustedClockService(
        sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
      );
      expect(service.nowMsTrusted(), 100000);

      wallMs = 0;
      monotonicMs = 1000;
      expect(service.nowMsTrusted(), 100000);
      expect(service.lastJudgement, ClockJudgement.rewind);
    });
  });

  group(
    'TrustedClockService: recoverable forward-jump fix (điểm mấu chốt IDEA-40)',
    () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        final storage = StorageService(await SharedPreferences.getInstance());
        Get.put(storage, permanent: true);
      });
      tearDown(Get.reset);

      test(
        'nhảy đồng hồ 1 năm trong khi app vẫn đang chạy: baseline KHÔNG bị đẩy lên tận 1 năm sau',
        () {
          var wallMs = 0;
          var monotonicMs = 0;
          final service = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          expect(service.nowMsTrusted(), 0);

          // Nhảy 1 năm nhưng chỉ 500ms xử lý thật trôi qua (monotonic).
          const oneYearMs = 365 * 24 * 60 * 60 * 1000;
          wallMs = oneYearMs;
          monotonicMs = 500;

          expect(service.nowMsTrusted(), 0); // KHÔNG phải oneYearMs
          expect(service.lastJudgement, ClockJudgement.suspiciousForwardJump);
        },
      );

      test(
        'SAU KHI quarantine cú nhảy 1 năm: đồng hồ tiếp tục trôi bình thường từ mốc TRƯỚC cú nhảy (không bị khoá nhiều năm)',
        () {
          var wallMs = 0;
          var monotonicMs = 0;
          final service = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          service.nowMsTrusted(); // baseline = 0

          const oneYearMs = 365 * 24 * 60 * 60 * 1000;
          wallMs = oneYearMs;
          monotonicMs = 500;
          expect(service.nowMsTrusted(), 0); // bị quarantine

          // Người dùng tự sửa lại đồng hồ về đúng thực tế — chỉ vài giây
          // sau (theo mốc TRƯỚC cú nhảy), không phải hàng năm.
          wallMs = 5000;
          monotonicMs = 5500; // ~5s trôi qua thật (monotonic) kể từ mốc trước
          expect(service.nowMsTrusted(), 5000);
          expect(service.lastJudgement, ClockJudgement.normal);
        },
      );

      test(
        'nhiều cú nhảy nghi vấn liên tiếp đều bị quarantine như nhau, không cộng dồn sai',
        () {
          var wallMs = 0;
          var monotonicMs = 0;
          final service = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          service.nowMsTrusted();

          for (var i = 1; i <= 3; i++) {
            wallMs = 365 * 24 * 60 * 60 * 1000 * i;
            monotonicMs = 500 * i;
            expect(service.nowMsTrusted(), 0);
            expect(service.lastJudgement, ClockJudgement.suspiciousForwardJump);
          }
        },
      );
    },
  );

  group(
    'TrustedClockService: reboot (giới hạn đã biết, không phải regression mới)',
    () {
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        final storage = StorageService(await SharedPreferences.getInstance());
        Get.put(storage, permanent: true);
      });
      tearDown(Get.reset);

      test(
        'reboot với wall time tăng hợp lý: baseline tiến lên bình thường',
        () {
          var wallMs = 1000;
          var monotonicMs = 500000; // "process cũ" đã chạy lâu
          final service = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          service.nowMsTrusted();

          // "Process mới" — monotonic reset về nhỏ (Stopwatch mới).
          wallMs = 2000;
          monotonicMs = 10;
          final reloaded = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          expect(reloaded.nowMsTrusted(), 2000);
          expect(reloaded.lastJudgement, ClockJudgement.reboot);
        },
      );

      test(
        'reboot với wall time lùi so với baseline đã lưu: vẫn giữ nguyên baseline cũ (không regression)',
        () {
          var wallMs = 100000;
          var monotonicMs = 500000;
          final service = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          service.nowMsTrusted();

          wallMs = 1000; // "process mới" nhưng wall time thấp hơn baseline cũ
          monotonicMs = 10;
          final reloaded = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          expect(reloaded.nowMsTrusted(), 100000);
        },
      );

      test(
        'GIỚI HẠN ĐÃ BIẾT (không phải bug mới): kill app rồi vặn đồng hồ rồi mở lại VẪN qua được — giống hệt hạn chế đã ghi trong clamped_clock.dart',
        () {
          // monotonicMs=500000 mô phỏng "process cũ đã chạy 1 khoảng lâu"
          // trước khi bị kill — cần thiết để lần đọc kế tiếp (process MỚI,
          // Stopwatch reset về nhỏ) thực sự bị chấm "reboot" (monotonic đi
          // lùi), đúng bản chất phép thử này muốn mô phỏng.
          var wallMs = 0;
          var monotonicMs = 500000;
          final service = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );
          service.nowMsTrusted();

          // Kill app (mô phỏng bằng instance MỚI, monotonic reset) SAU KHI
          // đã vặn đồng hồ xa — không có mốc monotonic nào trong process
          // mới để phát hiện đây là cú nhảy đáng ngờ.
          const oneYearMs = 365 * 24 * 60 * 60 * 1000;
          wallMs = oneYearMs;
          monotonicMs = 10;
          final reloaded = TrustedClockService(
            sampleNow: () =>
                ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          );

          expect(reloaded.nowMsTrusted(), oneYearMs);
          expect(reloaded.lastJudgement, ClockJudgement.reboot);
        },
      );
    },
  );

  group('TrustedClockService: lastJudgement', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      Get.put(storage, permanent: true);
    });
    tearDown(Get.reset);

    test('null trước lần gọi đầu tiên (chưa có gì để so sánh)', () {
      final service = TrustedClockService(
        sampleNow: () => const ClockSample(wallMs: 0, monotonicMs: 0),
      );
      expect(service.lastJudgement, isNull);
    });
  });

  group('TrustedClockService: reconcileWithTrustedSource', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      Get.put(storage, permanent: true);
    });
    tearDown(Get.reset);

    test('không cấu hình trustedTimeSource: no-op, không throw', () async {
      final service = TrustedClockService(
        sampleNow: () => const ClockSample(wallMs: 0, monotonicMs: 0),
      );
      service.nowMsTrusted();

      await expectLater(service.reconcileWithTrustedSource(), completes);
    });

    test(
      'trustedTimeSource trả về null (offline): no-op, không throw',
      () async {
        final service = TrustedClockService(
          sampleNow: () => const ClockSample(wallMs: 0, monotonicMs: 0),
          trustedTimeSource: _FakeTrustedTimeSource(null),
        );
        service.nowMsTrusted();

        await service.reconcileWithTrustedSource();
        expect(service.nowMsTrusted(), 0);
      },
    );

    test(
      'trustedTimeSource xác nhận mốc CAO HƠN baseline đang bị quarantine: tái neo ngay lập tức',
      () async {
        var wallMs = 0;
        var monotonicMs = 0;
        const oneYearMs = 365 * 24 * 60 * 60 * 1000;
        final source = _FakeTrustedTimeSource(oneYearMs);
        final service = TrustedClockService(
          sampleNow: () =>
              ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          trustedTimeSource: source,
        );
        service.nowMsTrusted(); // baseline = 0

        wallMs = oneYearMs;
        monotonicMs = 500;
        expect(service.nowMsTrusted(), 0); // quarantine như thường lệ

        await service.reconcileWithTrustedSource();

        // Đọc lại baseline đã được tái neo — gọi nowMsTrusted() với 1
        // sample "bình thường" ngay sau baseline mới để xác nhận nó thực
        // sự đã tiến lên oneYearMs, không phải vẫn kẹt ở 0.
        wallMs = oneYearMs + 100;
        monotonicMs = 600;
        expect(service.nowMsTrusted(), oneYearMs + 100);
      },
    );

    test(
      'trustedTimeSource trả về mốc THẤP HƠN baseline: không lùi (no-op)',
      () async {
        var wallMs = 100000;
        var monotonicMs = 0;
        final service = TrustedClockService(
          sampleNow: () =>
              ClockSample(wallMs: wallMs, monotonicMs: monotonicMs),
          trustedTimeSource: _FakeTrustedTimeSource(50),
        );
        service.nowMsTrusted();

        await service.reconcileWithTrustedSource();

        wallMs = 100001;
        monotonicMs = 1;
        expect(service.nowMsTrusted(), 100001);
      },
    );
  });

  group('TrustedClockService: static monotonic reference dùng chung process', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(await SharedPreferences.getInstance());
      Get.put(storage, permanent: true);
    });
    tearDown(Get.reset);

    test(
      '2 instance KHÔNG truyền sampleNow tuỳ chỉnh (dùng Stopwatch thật) gọi liên tiếp không bị coi là reboot lẫn nhau',
      () {
        final first = TrustedClockService();
        first.nowMsTrusted();

        final second = TrustedClockService();
        second.nowMsTrusted();

        // Nếu mỗi instance có Stopwatch riêng (reset về 0), instance thứ 2
        // sẽ luôn bị chấm "reboot" ngay cả khi vẫn cùng 1 process — sai.
        expect(second.lastJudgement, isNot(ClockJudgement.reboot));
      },
    );
  });
}
