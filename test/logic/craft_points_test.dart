import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/boss_tile.dart';
import 'package:pop_star_blast/logic/craft_points.dart';

void main() {
  group('craftPointsForRemainingCells', () {
    test('bàn trống → 0 craft point', () {
      final grid = List.generate(4, (_) => List<int?>.generate(4, (_) => null));
      expect(craftPointsForRemainingCells(grid), 0);
    });

    test('N cell màu thường → floor(N / cellsPerCraftPoint)', () {
      final grid8 = [
        [0, 1, 2, null],
        [3, 0, null, null],
        [null, null, null, null],
        [null, null, null, null],
      ]; // 6 cell màu → 6 ~/ 4 = 1
      expect(craftPointsForRemainingCells(grid8), 1);

      final grid16 = List.generate(4, (_) => List<int?>.generate(4, (_) => 0));
      expect(craftPointsForRemainingCells(grid16), 16 ~/ cellsPerCraftPoint);
    });

    test('cell boss tile (mã âm) bị loại khỏi số đếm', () {
      final grid = [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [bossTileIdBase, bossTileIdBase, bossTileIdBase, bossTileIdBase],
      ]; // 12 cell màu thường + 4 cell boss → chỉ tính 12
      expect(craftPointsForRemainingCells(grid), 12 ~/ cellsPerCraftPoint);
    });
  });
}
