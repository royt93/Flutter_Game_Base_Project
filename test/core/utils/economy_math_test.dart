import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/economy_math.dart';

void main() {
  group('regenEnergy', () {
    test('đã đầy tim: không đổi count/lastMs, không trừ ngày nào', () {
      final result = regenEnergy(
        count: 5,
        maxEnergy: 5,
        lastMs: 1000,
        nowMs: 999999,
        intervalMs: 100,
      );

      expect(result.count, 5);
      expect(result.lastMs, 1000);
    });

    test('chưa qua 1 tick: không đổi gì', () {
      final result = regenEnergy(
        count: 2,
        maxEnergy: 5,
        lastMs: 1000,
        nowMs: 1050,
        intervalMs: 100,
      );

      expect(result.count, 2);
      expect(result.lastMs, 1000);
    });

    test('qua đúng 1 tick: cộng 1, lastMs tiến đúng 1 interval', () {
      final result = regenEnergy(
        count: 2,
        maxEnergy: 5,
        lastMs: 1000,
        nowMs: 1100,
        intervalMs: 100,
      );

      expect(result.count, 3);
      expect(result.lastMs, 1100);
    });

    test('qua nhiều tick cùng lúc: cộng đủ, giữ lại phần dư (sub-tick)', () {
      final result = regenEnergy(
        count: 0,
        maxEnergy: 5,
        lastMs: 1000,
        nowMs: 1350,
        intervalMs: 100,
      );

      // 3 tick trọn (300ms) từ 1000 -> 1300, còn dư 50ms chưa đủ 1 tick.
      expect(result.count, 3);
      expect(result.lastMs, 1300);
    });

    test(
      'số tick vượt quá phần còn thiếu: cap đúng ở maxEnergy, lastMs = nowMs',
      () {
        final result = regenEnergy(
          count: 3,
          maxEnergy: 5,
          lastMs: 1000,
          nowMs: 10000,
          intervalMs: 100,
        );

        expect(result.count, 5);
        expect(result.lastMs, 10000);
      },
    );

    group('BUG-69: validate intervalMs > 0', () {
      test('intervalMs == 0: throw ArgumentError thay vì '
          'IntegerDivisionByZeroException', () {
        expect(
          () => regenEnergy(
            count: 2,
            maxEnergy: 5,
            lastMs: 1000,
            nowMs: 999999,
            intervalMs: 0,
          ),
          throwsArgumentError,
        );
      });

      test('intervalMs âm cũng bị chặn tương tự', () {
        expect(
          () => regenEnergy(
            count: 2,
            maxEnergy: 5,
            lastMs: 1000,
            nowMs: 999999,
            intervalMs: -100,
          ),
          throwsArgumentError,
        );
      });

      test(
        // Validate PHẢI chạy TRƯỚC nhánh early-return "đã đầy tim" — nếu
        // không, intervalMs<=0 chỉ crash khi count CHƯA đầy, ẩn bug tuỳ
        // trạng thái năng lượng hiện tại thay vì báo lỗi nhất quán.
        'intervalMs == 0 vẫn throw NGAY CẢ KHI count đã đầy (validate chạy '
        'trước early-return, không phụ thuộc trạng thái)',
        () {
          expect(
            () => regenEnergy(
              count: 5,
              maxEnergy: 5,
              lastMs: 1000,
              nowMs: 999999,
              intervalMs: 0,
            ),
            throwsArgumentError,
          );
        },
      );

      test('intervalMs > 0 hành vi không đổi (giữ nguyên như trước fix)', () {
        final result = regenEnergy(
          count: 2,
          maxEnergy: 5,
          lastMs: 1000,
          nowMs: 1200,
          intervalMs: 100,
        );

        expect(result.count, 4);
        expect(result.lastMs, 1200);
      });
    });

    test('nowMs lùi lại trước lastMs (giả lập vặn đồng hồ): không tick âm', () {
      final result = regenEnergy(
        count: 2,
        maxEnergy: 5,
        lastMs: 1000,
        nowMs: 500,
        intervalMs: 100,
      );

      expect(result.count, 2);
      expect(result.lastMs, 1000);
    });
  });

  group('offlineEarnings', () {
    test('chưa qua thời gian nào: earnings = 0', () {
      expect(
        offlineEarnings(
          lastClaimedMs: 1000,
          nowMs: 1000,
          maxOfflineCapMs: 100000,
          productionRatePerSecond: 1.0,
        ),
        0,
      );
    });

    test('tính đúng earnings = elapsed(s) * rate khi chưa vượt cap', () {
      final earnings = offlineEarnings(
        lastClaimedMs: 0,
        nowMs: 5000, // 5 giây
        maxOfflineCapMs: 100000,
        productionRatePerSecond: 2.0,
      );

      expect(earnings, 10.0);
    });

    test('vượt cap: chỉ tính earnings trong giới hạn cap', () {
      final earnings = offlineEarnings(
        lastClaimedMs: 0,
        nowMs: 1000000, // rất xa
        maxOfflineCapMs: 5000, // cap 5 giây
        productionRatePerSecond: 2.0,
      );

      expect(earnings, 10.0); // đúng bằng 5s * 2.0, không vượt
    });

    test('maxOfflineCapMs âm throw ArgumentError', () {
      expect(
        () => offlineEarnings(
          lastClaimedMs: 0,
          nowMs: 1000,
          maxOfflineCapMs: -1,
          productionRatePerSecond: 1.0,
        ),
        throwsArgumentError,
      );
    });

    test('productionRatePerSecond âm/NaN/Infinity throw ArgumentError', () {
      expect(
        () => offlineEarnings(
          lastClaimedMs: 0,
          nowMs: 1000,
          maxOfflineCapMs: 5000,
          productionRatePerSecond: -1.0,
        ),
        throwsArgumentError,
      );
      expect(
        () => offlineEarnings(
          lastClaimedMs: 0,
          nowMs: 1000,
          maxOfflineCapMs: 5000,
          productionRatePerSecond: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => offlineEarnings(
          lastClaimedMs: 0,
          nowMs: 1000,
          maxOfflineCapMs: 5000,
          productionRatePerSecond: double.infinity,
        ),
        throwsArgumentError,
      );
    });

    test(
      'nowMs lùi lại trước lastClaimedMs (vặn đồng hồ): earnings = 0, không âm',
      () {
        final earnings = offlineEarnings(
          lastClaimedMs: 5000,
          nowMs: 1000,
          maxOfflineCapMs: 100000,
          productionRatePerSecond: 1.0,
        );

        expect(earnings, 0);
      },
    );
  });

  group('prestigeMultiplier', () {
    test('0 relic (chưa từng prestige) -> multiplier = 1 (không đổi)', () {
      expect(
        prestigeMultiplier(relics: 0, bonusPerRelic: 0.1),
        1.0,
      );
    });

    test('công thức đúng: 1 + relics * bonusPerRelic', () {
      expect(prestigeMultiplier(relics: 5, bonusPerRelic: 0.1), 1.5);
      expect(prestigeMultiplier(relics: 10, bonusPerRelic: 0.25), 3.5);
    });

    test('bonusPerRelic = 0 -> multiplier luôn = 1 bất kể relics', () {
      expect(prestigeMultiplier(relics: 999, bonusPerRelic: 0), 1.0);
    });

    test('relics âm -> throw ArgumentError', () {
      expect(
        () => prestigeMultiplier(relics: -1, bonusPerRelic: 0.1),
        throwsArgumentError,
      );
    });

    test('bonusPerRelic âm -> throw ArgumentError', () {
      expect(
        () => prestigeMultiplier(relics: 5, bonusPerRelic: -0.1),
        throwsArgumentError,
      );
    });

    test('bonusPerRelic NaN/infinite -> throw ArgumentError', () {
      expect(
        () => prestigeMultiplier(relics: 5, bonusPerRelic: double.nan),
        throwsArgumentError,
      );
      expect(
        () => prestigeMultiplier(relics: 5, bonusPerRelic: double.infinity),
        throwsArgumentError,
      );
    });
  });
}
