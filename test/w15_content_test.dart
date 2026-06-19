import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/logic/settle.dart';

/// Wave 15 Phase 5 — Nội dung: 150 màn, thế giới 6-8, weave bố cục/dòng chảy/cage.
void main() {
  group('Wave 15 — nội dung thế giới 6-8 (màn 101-150)', () {
    test('150 màn, 8 thế giới, weave vào thế giới 6-8', () {
      expect(kLevelCount, 150);
      expect(kLevels.length, 150);
      expect(kWorlds.length, 8);
      // thế giới 6-8 đúng phạm vi.
      expect(worldOfLevel(101).index, 6);
      expect(worldOfLevel(120).index, 6);
      expect(worldOfLevel(121).index, 7);
      expect(worldOfLevel(141).index, 8);
      expect(worldOfLevel(150).index, 8);
    });

    test('accentForWorld 6-8 không lỗi (wrap màu)', () {
      for (int w = 6; w <= 8; w++) {
        expect(() => NeonTheme.accentForWorld(w), returnsNormally);
      }
    });

    test('weave bố cục: màn có layout đúng (tường/lỗ + no-drop)', () {
      for (final idx in kLayoutLevels.keys) {
        final lv = kLevels[idx - 1];
        expect(lv.layout, isNotNull, reason: 'màn $idx phải có layout');
        expect(lv.objective, ObjectiveType.score); // weave vào màn score
      }
      // 145 có ô no-drop.
      final l145 = kLevels[144].layout!;
      final hasNoDrop = l145.any((row) => row.contains(CellKind.noDrop));
      expect(hasNoDrop, isTrue);
    });

    test('weave dòng chảy: màn có flow đúng (Gravity Streams)', () {
      for (final idx in kFlowLevels.keys) {
        final lv = kLevels[idx - 1];
        expect(lv.flow, isNotNull, reason: 'màn $idx phải có flow');
        // có ít nhất 1 ô KHÁC down (mới là stream).
        final hasNonDown =
            lv.flow!.any((row) => row.any((f) => f != FlowDir.down));
        expect(hasNonDown, isTrue);
      }
    });

    test('weave cage thế giới 6-8 ({114,138}) = clearObstacle + cage', () {
      for (final idx in {114, 138}) {
        final lv = kLevels[idx - 1];
        expect(lv.objective, ObjectiveType.clearObstacle);
        expect(lv.obstacle, ObstacleType.cage);
      }
    });

    test('màn 101-150 KHÔNG có objective riêng (endless/boss/soda)', () {
      for (int i = 100; i < 150; i++) {
        expect(
          kLevels[i].objective,
          isNot(anyOf(ObjectiveType.endless, ObjectiveType.boss,
              ObjectiveType.soda)),
        );
      }
    });
  });
}
