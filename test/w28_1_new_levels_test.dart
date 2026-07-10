import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

/// Wave 28.1 — 8 level mới (201-208), nối dài World 10, dùng
/// Flow/Conveyor/Portal/Dispenser. KHÔNG đụng level cũ 1-200.
void main() {
  group('W28.1 — kLevelCount mở rộng 200 → 208', () {
    test('kLevels có đúng 208 phần tử, index liên tục', () {
      expect(kLevelCount, 208);
      expect(kLevels.length, 208);
      for (int i = 0; i < kLevels.length; i++) {
        expect(kLevels[i].index, i + 1);
      }
    });

    test('World 10 nối dài tới 208, không đụng level cũ', () {
      final w10 = kWorlds.firstWhere((w) => w.index == 10);
      expect(w10.startLevel, 171);
      expect(w10.endLevel, 208);
    });

    test(
      'level 208 (cuối World10 mới) là superHard, world 1-8 không đổi tier',
      () {
        // World10 nối dài → band tier dịch theo endLevel mới (200→208), nên
        // level 200 không còn là biên world nữa (ratio tổng thể vẫn ổn, xem
        // w16_tiers_test). Biên world mới là 208.
        expect(levelTier(208), LevelTier.superHard);
        // Level giữa world 1-8 (không đụng, tránh trùng biên endLevel).
        for (final idx in [10, 55, 85, 145]) {
          expect(levelTier(idx), isNot(LevelTier.superHard));
        }
      },
    );
  });

  group('W28.1 — mechanic gắn vào 201-208 độc lập objective', () {
    test('202 có Conveyor', () {
      expect(kConveyorSpec.containsKey(202), isTrue);
    });

    test('204 có Portal', () {
      expect(kPortalSpec.containsKey(204), isTrue);
    });

    test('206 có Dispenser', () {
      expect(kDispenserSpec.containsKey(206), isTrue);
    });

    test('205 (score objective duy nhất trong 201-208) có Flow', () {
      final lv = kLevels[204]; // index 205
      expect(lv.index, 205);
      expect(lv.objective, ObjectiveType.score);
      expect(kFlowLevels.containsKey(205), isTrue);
    });

    test('201/203/207/208 là level nghỉ (không mechanic đặc biệt)', () {
      for (final idx in [201, 203, 207, 208]) {
        expect(kConveyorSpec.containsKey(idx), isFalse);
        expect(kPortalSpec.containsKey(idx), isFalse);
        expect(kDispenserSpec.containsKey(idx), isFalse);
      }
    });
  });

  group('W28.1 — tham số 201-208 hợp lệ (không NaN/âm, moves>0)', () {
    test('mọi level mới có rows/cols/moves hợp lệ', () {
      for (final lv in kLevels.sublist(200)) {
        expect(lv.rows, greaterThanOrEqualTo(5));
        expect(lv.cols, greaterThanOrEqualTo(5));
        expect(lv.moves, greaterThan(0));
      }
    });
  });
}
