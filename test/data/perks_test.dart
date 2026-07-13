import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/data/perks.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';

void main() {
  group('worldsCompleted', () {
    test('chưa mở khoá level nào ngoài world 1 -> 0 world xong', () {
      expect(worldsCompleted(1), 0);
      expect(worldsCompleted(20), 0);
    });

    test('unlockedLevel vừa qua khỏi endId world -> world đó tính xong', () {
      expect(worldsCompleted(21), 1); // xong world 1 (id 1-20)
      expect(worldsCompleted(41), 2); // xong world 1+2
      expect(worldsCompleted(61), 3); // xong world 1+2+3
    });
  });

  group('unlockedPerks', () {
    test('mở khoá đúng theo world hoàn thành', () {
      expect(unlockedPerks(1), isEmpty);
      expect(unlockedPerks(21).map((p) => p.id), ['extra_undo']);
      expect(unlockedPerks(41).map((p) => p.id), ['extra_undo', 'move_hint']);
      expect(unlockedPerks(61).map((p) => p.id), [
        'extra_undo',
        'move_hint',
        'coin_bonus',
      ]);
    });
  });

  group('GameController.togglePerkSelection', () {
    test('thêm perk mới khi chưa active', () {
      expect(GameController.togglePerkSelection([], 'extra_undo'), [
        'extra_undo',
      ]);
    });

    test('bỏ perk khi đã active', () {
      expect(
        GameController.togglePerkSelection(['extra_undo'], 'extra_undo'),
        isEmpty,
      );
    });

    test('giới hạn tối đa 2 active — bỏ qua nếu đã đủ', () {
      final active = ['extra_undo', 'move_hint'];
      expect(GameController.togglePerkSelection(active, 'coin_bonus'), active);
    });

    test('vẫn bỏ được perk đang active dù đã đủ 2', () {
      final active = ['extra_undo', 'move_hint'];
      expect(GameController.togglePerkSelection(active, 'move_hint'), [
        'extra_undo',
      ]);
    });
  });
}
