import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/offline_progression_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/economy_sim.dart';

int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  group('simulateEconomy: unit', () {
    test('ngày 1, chưa qua session nào vượt tick: energy giảm đúng, currency = 0 ở session đầu', () {
      final snapshots = simulateEconomy(
        const EconomyScenario(
          days: 1,
          sessionsPerDay: 1,
          energyPerSession: 2,
          maxEnergy: 5,
          refillIntervalMs: 1000000,
          sessionSpacingMs: 100,
          maxOfflineCapMs: 100000,
          productionRatePerSecond: 1.0,
        ),
      );

      expect(snapshots, hasLength(1));
      // Session duy nhất chạy tại nowMs=0 == lastClaimedMs=0 ban đầu -> 0 earnings.
      expect(snapshots.single.cumulativeCurrency, 0);
      expect(snapshots.single.endEnergyCount, 3); // 5 - 2
    });

    test('không đủ năng lượng cho session: không trừ (giữ nguyên, không âm)', () {
      final snapshots = simulateEconomy(
        const EconomyScenario(
          days: 1,
          sessionsPerDay: 3,
          energyPerSession: 4,
          maxEnergy: 5,
          refillIntervalMs: 1000000000, // không kịp hồi trong suốt kịch bản
          sessionSpacingMs: 100,
          maxOfflineCapMs: 100000,
          productionRatePerSecond: 0,
        ),
      );

      // Session 1: 5 - 4 = 1. Session 2: 1 < 4 -> giữ nguyên 1. Session 3: giữ nguyên 1.
      expect(snapshots.single.endEnergyCount, 1);
    });

    test('trả về đúng số ngày yêu cầu, mỗi ngày 1 snapshot', () {
      final snapshots = simulateEconomy(
        const EconomyScenario(
          days: 7,
          sessionsPerDay: 2,
          energyPerSession: 1,
          maxEnergy: 5,
          refillIntervalMs: 1000,
          sessionSpacingMs: 100,
          maxOfflineCapMs: 100000,
          productionRatePerSecond: 0.1,
        ),
      );

      expect(snapshots, hasLength(7));
      expect(snapshots.map((s) => s.day).toList(), List.generate(7, (i) => i + 1));
    });

    test('currency tích luỹ đơn điệu tăng qua các ngày (không giảm)', () {
      final snapshots = simulateEconomy(
        const EconomyScenario(
          days: 5,
          sessionsPerDay: 2,
          energyPerSession: 1,
          maxEnergy: 5,
          refillIntervalMs: 1000,
          sessionSpacingMs: 3600000,
          maxOfflineCapMs: 100000000,
          productionRatePerSecond: 0.5,
        ),
      );

      for (var i = 1; i < snapshots.length; i++) {
        expect(
          snapshots[i].cumulativeCurrency,
          greaterThanOrEqualTo(snapshots[i - 1].cumulativeCurrency),
        );
      }
    });
  });

  group('parseArgs', () {
    test('không truyền arg nào: giữ nguyên default', () {
      final options = parseArgs(const []);
      expect(options['days'], 30);
      expect(options['productionRatePerSecond'], 0.01);
    });

    test('ghi đè đúng key hợp lệ, bỏ qua key không tồn tại và giá trị hỏng', () {
      final options = parseArgs(const [
        '--days=10',
        '--productionRatePerSecond=0.5',
        '--unknownKey=999',
        '--maxEnergy=notAnInt',
      ]);

      expect(options['days'], 10);
      expect(options['productionRatePerSecond'], 0.5);
      expect(options.containsKey('unknownKey'), isFalse);
      expect(options['maxEnergy'], 5); // giữ default vì "notAnInt" parse lỗi
    });
  });

  group('cross-check: simulateEconomy khớp đúng với service thật', () {
    test(
      'chạy EnergyService/OfflineProgressionService thật qua cùng kịch bản thời gian, kết quả cuối cùng khớp 100% với simulateEconomy',
      () async {
        const scenario = EconomyScenario(
          days: 3,
          sessionsPerDay: 2,
          energyPerSession: 1,
          maxEnergy: 3,
          refillIntervalMs: 10 * 60 * 1000, // 10 phút
          sessionSpacingMs: 60 * 60 * 1000, // 1 tiếng
          maxOfflineCapMs: 4 * 60 * 60 * 1000, // cap 4 tiếng
          productionRatePerSecond: 0.5,
        );

        final simulated = simulateEconomy(scenario);

        final energy = EnergyService(
          maxEnergy: scenario.maxEnergy,
          refillInterval: Duration(milliseconds: scenario.refillIntervalMs),
        );
        final offline = OfflineProgressionService(
          maxOfflineCap: Duration(milliseconds: scenario.maxOfflineCapMs),
        );

        // +5 phút đệm: đảm bảo MỌI mốc "now" giả lập (kể cả nowMs == 0 ở
        // session đầu) luôn lớn hơn đồng hồ thật tại thời điểm đó, để
        // nowMsClamped() luôn trả về đúng giá trị đã set qua setNowMs thay
        // vì lỡ đọc phải đồng hồ thật (dù chỉ lệch vài ms do thời gian
        // thực thi test) — cùng lớp lỗi timing đã gặp ở
        // daily_quest_service_test.dart/season_event_service_test.dart.
        final baseMs = _realMs + const Duration(minutes: 5).inMilliseconds;
        var realCurrency = 0.0;
        var nowMs = 0;

        for (var day = 1; day <= scenario.days; day++) {
          for (var session = 0; session < scenario.sessionsPerDay; session++) {
            await storage.setInt(StorageKeys.maxMsSeen, baseMs + nowMs);

            realCurrency += await offline.claim(
              scenario.productionRatePerSecond,
            );
            energy.consumeEnergy(scenario.energyPerSession);

            nowMs += scenario.sessionSpacingMs;
          }
        }

        expect(realCurrency, simulated.last.cumulativeCurrency);
        expect(energy.currentEnergy, simulated.last.endEnergyCount);
      },
    );
  });

  group('CLI: chạy độc lập qua dart run (không cần Flutter runtime)', () {
    test(
      'dart run tool/economy_sim.dart in ra đúng bảng, exit code 0',
      () async {
        final result = await Process.run('dart', [
          'run',
          'tool/economy_sim.dart',
          '--days=2',
        ]);

        expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
        final output = result.stdout as String;
        expect(output, contains('day'));
        expect(output, contains('endEnergy'));
        expect(output, contains('cumulativeCurrency'));
        // Đúng 2 ngày mô phỏng + 1 dòng header = 3 dòng (bỏ dòng rỗng cuối).
        final lines = output.trim().split('\n');
        expect(lines, hasLength(3));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
