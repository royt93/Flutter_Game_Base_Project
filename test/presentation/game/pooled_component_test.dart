import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/object_pool.dart';
import 'package:roy_casual_kit/presentation/game/pooled_component.dart';

class _PooledDot extends PositionComponent with PooledComponent {
  bool resetCalled = false;
}

void main() {
  testWidgets(
    'removeFromParent() tự động release về đúng pool, gọi đúng reset (FEAT-48)',
    (tester) async {
      final game = FlameGame();
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await game.toBeLoaded();
      await tester.pump();

      final pool = ObjectPool<_PooledDot>(
        create: () => _PooledDot(),
        reset: (d) => d.resetCalled = true,
      );

      final dot = pool.acquire();
      dot.attachToPool(() => pool.release(dot));
      game.add(dot);
      await tester.pump();

      expect(pool.activeCount, 1);
      expect(pool.freeCount, 0);

      dot.removeFromParent();
      await tester.pump();

      expect(pool.activeCount, 0);
      expect(pool.freeCount, 1);
      expect(dot.resetCalled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'acquire lại sau removeFromParent(): tái sử dụng đúng instance cũ, gắn lại đúng pool',
    (tester) async {
      final game = FlameGame();
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await game.toBeLoaded();
      await tester.pump();

      final pool = ObjectPool<_PooledDot>(create: () => _PooledDot());

      final first = pool.acquire();
      first.attachToPool(() => pool.release(first));
      game.add(first);
      await tester.pump();
      first.removeFromParent();
      await tester.pump();

      final second = pool.acquire();
      expect(identical(first, second), isTrue);

      second.attachToPool(() => pool.release(second));
      game.add(second);
      await tester.pump();
      second.removeFromParent();
      await tester.pump();

      expect(pool.activeCount, 0);
      expect(pool.freeCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'component chưa từng attachToPool: removeFromParent() không throw (an toàn khi dùng ngoài pool)',
    (tester) async {
      final game = FlameGame();
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await game.toBeLoaded();
      await tester.pump();

      final standalone = _PooledDot();
      game.add(standalone);
      await tester.pump();

      standalone.removeFromParent();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
