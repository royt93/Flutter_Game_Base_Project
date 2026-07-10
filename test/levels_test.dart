import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

void main() {
  group('kLevels — tính hợp lệ', () {
    test('có đúng kLevelCount level (W28.1: 208)', () {
      expect(kLevels.length, kLevelCount);
      expect(kLevels.length, 208);
    });

    test('index liên tục từ 1', () {
      for (int i = 0; i < kLevels.length; i++) {
        expect(kLevels[i].index, i + 1);
      }
    });

    test('tham số cơ bản hợp lệ', () {
      for (final lv in kLevels) {
        expect(lv.rows, greaterThanOrEqualTo(5));
        expect(lv.cols, greaterThanOrEqualTo(5));
        expect(lv.colorCount, inInclusiveRange(3, 6));
        expect(lv.moves, greaterThan(0));
      }
    });

    test('cấu hình mục tiêu nhất quán theo loại', () {
      for (final lv in kLevels) {
        switch (lv.objective) {
          case ObjectiveType.score:
            expect(
              lv.targetScore,
              greaterThan(0),
              reason: 'level ${lv.index} score cần targetScore > 0',
            );
            break;
          case ObjectiveType.collect:
            expect(lv.collectTarget, greaterThan(0));
            expect(lv.collectColor, isNotNull);
            break;
          case ObjectiveType.clearJelly:
            expect(lv.jelly, isNot(JellyPattern.none));
            break;
          case ObjectiveType.timeAttack:
            expect(lv.targetScore, greaterThan(0));
            expect(lv.timeLimit, greaterThan(0));
            break;
          case ObjectiveType.dropDown:
            expect(lv.dropTarget, greaterThan(0));
            break;
          case ObjectiveType.clearObstacle:
            expect(lv.obstacle, isNot(ObstacleType.none));
            expect(lv.obstaclePattern, isNot(JellyPattern.none));
            break;
          case ObjectiveType.order:
            expect(
              lv.orders,
              isNotEmpty,
              reason: 'level ${lv.index} order cần orders không rỗng',
            );
            break;
          case ObjectiveType.endless:
            fail('endless không được gắn vào màn thường (level ${lv.index})');
          case ObjectiveType.boss:
            fail('boss không được gắn vào màn thường (level ${lv.index})');
          case ObjectiveType.soda:
            fail('soda không được gắn vào màn thường (level ${lv.index})');
        }
      }
    });

    test('các màn thường phủ đủ 6 mục tiêu xoay vòng (không gồm endless)', () {
      final types = kLevels.map((l) => l.objective).toSet();
      expect(types, containsAll(kRotatingObjectives));
      expect(types, isNot(contains(ObjectiveType.endless)));
    });

    test('mọi màn dùng board 8x8 chuẩn (đồng nhất)', () {
      for (final lv in kLevels) {
        expect(lv.rows, 8, reason: 'level ${lv.index} rows != 8');
        expect(lv.cols, 8, reason: 'level ${lv.index} cols != 8');
      }
    });

    // Wave 12 — chống TÁI PHÁT "tường độ khó" (target phi lý so với lượt/thời
    // gian). Ngưỡng trần = mức khả thi tối đa cho người chơi gắn bó.
    test('đường cong KHẢ THI: target không vượt thông lượng (chống tường)', () {
      for (final lv in kLevels) {
        switch (lv.objective) {
          case ObjectiveType.score:
            // ≤ ~110đ/lượt (1 match-3 = 30đ → ~3-4 match-3/lượt là trần khả thi)
            expect(
              lv.targetScore,
              lessThanOrEqualTo(lv.moves * 110),
              reason:
                  'L${lv.index}: ${lv.targetScore}đ / ${lv.moves} lượt '
                  '= ${(lv.targetScore / lv.moves).round()}đ/lượt — quá cao',
            );
            break;
          case ObjectiveType.collect:
            // ≤ 1.5 gem mục tiêu/lượt (chỉ ~1/6 bàn là màu mục tiêu)
            expect(
              lv.collectTarget,
              lessThanOrEqualTo((lv.moves * 1.5).ceil()),
              reason:
                  'L${lv.index}: collect ${lv.collectTarget} / '
                  '${lv.moves} lượt — quá cao',
            );
            break;
          case ObjectiveType.timeAttack:
            // ≤ ~75đ/giây
            expect(
              lv.targetScore,
              lessThanOrEqualTo(lv.timeLimit * 75),
              reason:
                  'L${lv.index}: ${lv.targetScore}đ / ${lv.timeLimit}s '
                  '— quá cao',
            );
            break;
          default:
            break;
        }
      }
    });
  });

  group('kWorlds — thế giới', () {
    test('phủ liên tục toàn bộ 100 màn không chồng/lủng', () {
      expect(kWorlds.first.startLevel, 1);
      expect(kWorlds.last.endLevel, kLevelCount);
      for (int i = 0; i < kWorlds.length; i++) {
        expect(kWorlds[i].index, i + 1);
        if (i > 0) {
          expect(
            kWorlds[i].startLevel,
            kWorlds[i - 1].endLevel + 1,
            reason: 'thế giới ${kWorlds[i].index} không nối tiếp',
          );
        }
      }
    });

    test('mỗi màn thuộc đúng 1 thế giới', () {
      for (final lv in kLevels) {
        final owners = kWorlds.where((w) => w.contains(lv.index)).toList();
        expect(
          owners.length,
          1,
          reason: 'màn ${lv.index} thuộc ${owners.length} thế giới',
        );
      }
    });

    test('mỗi thế giới có ít nhất 10 màn và tối đa 50 màn', () {
      // Wave 15: W8 = 10 màn (finale ngắn). Wave 20.2: W10 = 30 màn (finale dài).
      // Quy tắc: mỗi world ≥10 và ≤50 màn; tổng = kLevelCount.
      int total = 0;
      for (final w in kWorlds) {
        final size = w.endLevel - w.startLevel + 1;
        expect(
          size,
          greaterThanOrEqualTo(10),
          reason: 'thế giới ${w.index} cần ≥10 màn',
        );
        expect(
          size,
          lessThanOrEqualTo(50),
          reason: 'thế giới ${w.index} tối đa 50 màn',
        );
        total += size;
      }
      expect(
        total,
        kLevelCount,
        reason: 'tổng màn từ kWorlds phải bằng kLevelCount',
      );
    });
  });

  group('winnability obstacle (chain/stone khoá swap)', () {
    // Còn ≥1 cặp ô TỰ DO (không obstacle) kề nhau → người chơi đổi được gem.
    // chain/stone khoá swap nên pattern dày (checker/all) sẽ làm bí cứng bàn.
    bool hasAdjacentFreePair(JellyPattern p, int rows, int cols) {
      bool free(int r, int c) => !patternHas(p, r, c, rows, cols);
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (!free(r, c)) continue;
          if (c + 1 < cols && free(r, c + 1)) return true;
          if (r + 1 < rows && free(r + 1, c)) return true;
        }
      }
      return false;
    }

    test('patternHas đúng (center chừa viền, checker xen kẽ, all phủ hết)', () {
      expect(patternHas(JellyPattern.all, 0, 0, 8, 8), isTrue);
      expect(patternHas(JellyPattern.none, 0, 0, 8, 8), isFalse);
      expect(patternHas(JellyPattern.checker, 0, 0, 8, 8), isTrue);
      expect(patternHas(JellyPattern.checker, 0, 1, 8, 8), isFalse);
      expect(patternHas(JellyPattern.center, 0, 0, 8, 8), isFalse); // góc tự do
      expect(patternHas(JellyPattern.center, 3, 3, 8, 8), isTrue); // giữa
    });

    test(
      'checker/all KHÔNG còn cặp ô tự do kề nhau (sẽ kẹt nếu khoá swap)',
      () {
        // bằng chứng vì sao chain/stone không được dùng checker/all
        expect(hasAdjacentFreePair(JellyPattern.checker, 8, 8), isFalse);
        expect(hasAdjacentFreePair(JellyPattern.all, 8, 8), isFalse);
        expect(hasAdjacentFreePair(JellyPattern.center, 8, 8), isTrue);
      },
    );

    test('mọi màn chain/stone luôn còn nước đi (không bí cứng)', () {
      final locked = kLevels.where(
        (l) =>
            l.obstacle == ObstacleType.chain ||
            l.obstacle == ObstacleType.stone,
      );
      expect(locked, isNotEmpty);
      for (final lv in locked) {
        expect(
          hasAdjacentFreePair(lv.obstaclePattern, lv.rows, lv.cols),
          isTrue,
          reason:
              'màn ${lv.index} (${lv.obstacle}, ${lv.obstaclePattern}) bí cứng — '
              'mọi nước đi bị khoá',
        );
      }
    });

    test('chain/stone không bao giờ dùng pattern all/checker', () {
      for (final lv in kLevels.where(
        (l) =>
            l.obstacle == ObstacleType.chain ||
            l.obstacle == ObstacleType.stone,
      )) {
        expect(
          lv.obstaclePattern,
          isNot(JellyPattern.all),
          reason: 'màn ${lv.index} stone/chain dùng all → kẹt',
        );
        expect(
          lv.obstaclePattern,
          isNot(JellyPattern.checker),
          reason: 'màn ${lv.index} stone/chain dùng checker → kẹt',
        );
      }
    });
  });
}
