import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

/// Wave 16 Phase 4 — Near-miss (cắt lượt Super-Hard) + RNG control (chiều pity-giúp).
void main() {
  group('Wave 16 — near-miss', () {
    test('CHỈ Super-Hard bị cắt kNearMissCut lượt; tier khác = 0', () {
      for (int i = 1; i <= kLevelCount; i++) {
        final cut = nearMissCutFor(i);
        if (levelTier(i) == LevelTier.superHard) {
          expect(cut, kNearMissEnabled ? kNearMissCut : 0, reason: 'L$i super');
        } else {
          expect(cut, 0, reason: 'L$i không super → không cắt');
        }
      }
    });

    test('Super-Hard có ÍT lượt hơn (near-miss đỉnh) so với màn nghỉ kề', () {
      // màn 20 = Super-Hard; màn 21 = relief (đầu TG2, +3 lượt).
      expect(levelTier(20), LevelTier.superHard);
      expect(isReliefLevel(21), isTrue);
      expect(kLevels[20].moves, greaterThan(kLevels[19].moves),
          reason: 'relief (21) phải nhiều lượt hơn Super-Hard (20)');
    });
  });

  group('Wave 16 — RNG control (biasRefillToTarget, CHIỀU GIÚP)', () {
    const thr = 2; // pityThreshold giả định
    const bias = 0.20;

    test('thua nhiều + collect + có màu + roll thấp → ÉP màu mục tiêu', () {
      expect(
          biasRefillToTarget(3, thr, ObjectiveType.collect, true, 0.1, bias),
          isTrue);
    });

    test('pity thấp → KHÔNG ép (không giúp khi chưa thua nhiều)', () {
      expect(
          biasRefillToTarget(1, thr, ObjectiveType.collect, true, 0.1, bias),
          isFalse);
    });

    test('KHÔNG phải collect → không ép', () {
      expect(biasRefillToTarget(5, thr, ObjectiveType.score, true, 0.1, bias),
          isFalse);
    });

    test('roll cao (≥bias) → không ép (chỉ ~20% lần)', () {
      expect(
          biasRefillToTarget(5, thr, ObjectiveType.collect, true, 0.5, bias),
          isFalse);
    });

    test('không có màu mục tiêu → không ép', () {
      expect(
          biasRefillToTarget(5, thr, ObjectiveType.collect, false, 0.1, bias),
          isFalse);
    });
  });
}
