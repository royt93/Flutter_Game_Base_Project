import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

/// Wave 16 Phase 1 — tier độ khó + sawtooth.
void main() {
  group('Wave 16 — difficulty tiers', () {
    test('phân bố ~70/25/5 (Normal/Hard/Super-Hard)', () {
      var n = 0, h = 0, s = 0;
      for (int i = 1; i <= kLevelCount; i++) {
        switch (levelTier(i)) {
          case LevelTier.normal:
            n++;
            break;
          case LevelTier.hard:
            h++;
            break;
          case LevelTier.superHard:
            s++;
            break;
        }
      }
      expect(n + h + s, kLevelCount);
      // dung sai rộng quanh mục tiêu 70/25/5.
      expect(n / kLevelCount, inInclusiveRange(0.60, 0.80), reason: 'Normal ~70%');
      expect(h / kLevelCount, inInclusiveRange(0.15, 0.32), reason: 'Hard ~25%');
      expect(s / kLevelCount, inInclusiveRange(0.03, 0.10), reason: 'Super ~5%');
    });

    test('Super-Hard = cuối mỗi thế giới (đỉnh)', () {
      for (final w in kWorlds) {
        expect(levelTier(w.endLevel), LevelTier.superHard,
            reason: 'cuối thế giới ${w.index}');
      }
    });

    test('Sawtooth: 2 màn đầu thế giới (trừ TG1) = relief + Normal', () {
      for (final w in kWorlds) {
        if (w.index == 1) continue;
        for (final lv in [w.startLevel, w.startLevel + 1]) {
          expect(isReliefLevel(lv), isTrue, reason: 'relief màn $lv');
          expect(levelTier(lv), LevelTier.normal);
        }
      }
      // thế giới 1 không có relief (không Super-Hard phía trước).
      expect(isReliefLevel(1), isFalse);
    });

    test('tất định: gọi 2 lần cùng index → cùng tier', () {
      for (int i = 1; i <= kLevelCount; i++) {
        expect(levelTier(i), levelTier(i));
      }
    });

    test('relief (đầu TG2 = 21) là Normal + được nới', () {
      expect(isReliefLevel(21), isTrue);
      expect(levelTier(21), LevelTier.normal);
    });

    test('đường cong vẫn KHẢ THI sau tier (score/collect/time đều ≤ ngưỡng)', () {
      // đếm số màn Super-Hard thực sự được kiểm cho từng loại → tránh test vacuous
      // (trước đây chỉ check objective==score, mà KHÔNG Super-Hard nào là score).
      var superCollect = 0, superTime = 0;
      for (final lv in kLevels) {
        final isSuper = levelTier(lv.index) == LevelTier.superHard;
        switch (lv.objective) {
          case ObjectiveType.score:
            // siết về sát thực: màn score gắt nhất ~76đ/lượt → ngưỡng 85 có RĂNG
            // (bắt over-tune vừa), không lỏng như 110 (gần như không bao giờ chạm).
            expect(lv.targetScore, lessThanOrEqualTo(lv.moves * 85),
                reason: 'L${lv.index} score tier=${levelTier(lv.index)}');
            break;
          case ObjectiveType.collect:
            // trần collect scale theo tier (≤1.15·moves ở Super) — vẫn ≤1.2·moves
            // (an toàn dưới ngưỡng winnable 1.5 của levels_test).
            expect(lv.collectTarget, lessThanOrEqualTo((lv.moves * 1.2).ceil()),
                reason: 'L${lv.index} collect tier=${levelTier(lv.index)}');
            if (isSuper) superCollect++;
            break;
          case ObjectiveType.timeAttack:
            // điểm/giây thực ~38 max (34×1.12) → ngưỡng 45đ/s sát thực (có RĂNG),
            // thay vì 60 quá lỏng.
            expect(lv.targetScore, lessThanOrEqualTo(lv.timeLimit * 45),
                reason: 'L${lv.index} time tier=${levelTier(lv.index)}');
            if (isSuper) superTime++;
            break;
          default:
            break;
        }
      }
      // Super-Hard rơi vào collect/timeAttack/clearObstacle (không score) → test
      // PHẢI chạm ≥1 Super-Hard collect & ≥1 Super-Hard time, nếu không là vacuous.
      expect(superCollect, greaterThanOrEqualTo(1),
          reason: 'phải kiểm ≥1 Super-Hard collect');
      expect(superTime, greaterThanOrEqualTo(1),
          reason: 'phải kiểm ≥1 Super-Hard timeAttack');
    });

    test('relief collect DỄ hơn Normal collect kề (răng cưa thật, không bị cap nuốt)',
        () {
      // tìm 1 cặp: màn relief collect & màn normal collect gần đó cùng vùng index
      // cao (đã qua điểm cap) → relief phải có tỉ lệ gem/lượt thấp hơn rõ rệt.
      LevelConfig? relief, normal;
      for (final lv in kLevels) {
        if (lv.objective != ObjectiveType.collect || lv.index < 100) continue;
        if (isReliefLevel(lv.index)) {
          relief ??= lv;
        } else if (levelTier(lv.index) == LevelTier.normal) {
          normal ??= lv;
        }
      }
      expect(relief, isNotNull);
      expect(normal, isNotNull);
      final reliefRate = relief!.collectTarget / relief.moves;
      final normalRate = normal!.collectTarget / normal.moves;
      expect(reliefRate, lessThan(normalRate),
          reason:
              'relief L${relief.index} ($reliefRate/lượt) phải dễ hơn normal L${normal.index} ($normalRate/lượt)');
    });

    test('Hard collect KHÓ hơn Normal collect kề (gap-fix: tier có răng thật)', () {
      // Wave 16 audit-fix HIGH-3: trước đây Hard==Normal trên collect (cap nuốt).
      // Nay Hard cap 1.08·moves → tỉ lệ gem/lượt cao hơn Normal rõ rệt.
      LevelConfig? hard, normal;
      for (final lv in kLevels) {
        if (lv.objective != ObjectiveType.collect || lv.index < 100) continue;
        final t = levelTier(lv.index);
        if (t == LevelTier.hard) {
          hard ??= lv;
        } else if (t == LevelTier.normal && !isReliefLevel(lv.index)) {
          normal ??= lv;
        }
      }
      expect(hard, isNotNull);
      expect(normal, isNotNull);
      expect(hard!.collectTarget / hard.moves,
          greaterThan(normal!.collectTarget / normal.moves),
          reason: 'Hard L${hard.index} phải gắt hơn Normal L${normal.index}');
    });

    test('Hard collect ít lượt hơn Normal collect index thấp hơn (move bite)', () {
      // collect KHÔNG cộng bonus-moves (khác score: spread/bomb) → so moves sạch.
      // L116 hard collect (base thấp do index cao, lại -1) vs L? normal collect.
      final hard = kLevels.firstWhere((lv) =>
          lv.objective == ObjectiveType.collect &&
          levelTier(lv.index) == LevelTier.hard &&
          lv.layout == null);
      final normal = kLevels.firstWhere((lv) =>
          lv.objective == ObjectiveType.collect &&
          levelTier(lv.index) == LevelTier.normal &&
          !isReliefLevel(lv.index) &&
          lv.index < hard.index &&
          lv.layout == null);
      // Normal index thấp hơn → base ≥ Hard; Hard lại -1 → Hard ≤ Normal lượt.
      expect(hard.moves, lessThanOrEqualTo(normal.moves),
          reason: 'Hard L${hard.index} (${hard.moves}) ≤ Normal L${normal.index} (${normal.moves})');
    });
  });
}
