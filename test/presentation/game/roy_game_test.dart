import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';

/// Minimal smoke test proving `flame`'s FlameGame/Component/GameWidget wiring
/// actually works end-to-end in this package (see FEAT-14 — the dependency
/// was declared but never exercised). Not a real game, no need for the
/// `flame_test` harness: a plain `GameWidget` inside `Material` + a bounded
/// `pump()` is enough (avoid `pumpAndSettle()` — like `NeonBg`, Flame's game
/// loop runs a permanent `Ticker` that never settles).
void main() {
  testWidgets('builds inside a GameWidget without throwing', (tester) async {
    final game = RoyGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: GameWidget(game: game)),
      ),
    );
    await game.toBeLoaded();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the circle toggles its tapped state', (tester) async {
    final game = RoyGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: GameWidget(game: game)),
      ),
    );
    await game.toBeLoaded();
    await tester.pump();

    final before = game.circle.tapped;

    await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
    // Bounded pump, not pumpAndSettle: Flame's game loop runs a permanent
    // Ticker (like NeonBg — see CLAUDE.md). This also flushes the
    // long-press-vs-tap gesture arena's internal timer so no Timer is left
    // pending at tearDown.
    await tester.pump(const Duration(milliseconds: 600));

    expect(game.circle.tapped, isNot(equals(before)));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BUG: world origin phải map đúng vào góc màn hình (top-left camera), '
    'không lệch theo kiểu camera-centered mặc định của Flame '
    '(FlameTrackedOverlay/IDEA-07 phụ thuộc đúng điều này)',
    (tester) async {
      final game = RoyGame();

      await tester.pumpWidget(
        MaterialApp(
          home: Material(child: GameWidget(game: game)),
        ),
      );
      await game.toBeLoaded();
      await tester.pump();

      // Flame's FlameGame auto-creates a CameraComponent with the DEFAULT
      // Anchor.center — world (0,0) maps to the VIEWPORT CENTER, not its
      // top-left corner. RoyGame's own components (TappableCircle.position
      // = size / 2) assume traditional top-left world coordinates instead
      // (matching how the circle visibly renders centered on screen) — a
      // mismatch that silently doubles any camera.localToGlobal() result
      // exactly at world position == size/2 (this exact case).
      final origin = game.camera.localToGlobal(Vector2.zero());
      expect(origin, Vector2.zero());

      final circleScreenPos = game.camera.localToGlobal(game.circle.position);
      expect(circleScreenPos, game.circle.position);
    },
  );

  group('ENH-81: sparkle burst (ObjectPool/PooledComponent demo)', () {
    testWidgets(
      'spawnSparkleBurst thêm đúng N SparkleParticle vào component tree',
      (tester) async {
        final game = RoyGame();
        await tester.pumpWidget(
          MaterialApp(home: Material(child: GameWidget(game: game))),
        );
        await game.toBeLoaded();
        await tester.pump();

        game.spawnSparkleBurst(Vector2(100, 100), count: 5);
        await tester.pump();

        expect(game.children.whereType<SparkleParticle>().length, 5);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tap vào circle kích hoạt burst sparkle', (tester) async {
      final game = RoyGame();
      await tester.pumpWidget(
        MaterialApp(home: Material(child: GameWidget(game: game))),
      );
      await game.toBeLoaded();
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.children.whereType<SparkleParticle>(), isNotEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'particle tự release về pool sau khi hết lifetime — burst sau tái '
      'sử dụng lại, không tạo mới vô hạn qua nhiều lần burst',
      (tester) async {
        final game = RoyGame();
        await tester.pumpWidget(
          MaterialApp(home: Material(child: GameWidget(game: game))),
        );
        await game.toBeLoaded();
        await tester.pump();

        game.spawnSparkleBurst(Vector2(50, 50), count: 4);
        await tester.pump();
        expect(game.children.whereType<SparkleParticle>().length, 4);

        // Đợi hết lifetime (0.6s) + margin cho chắc. `removeFromParent()`
        // (gọi trong `update()` khi `_age` vượt lifetime) chỉ ĐÁNH DẤU xoá —
        // Flame xử lý xoá thật khỏi `children` ở đầu lần update KẾ TIẾP, nên
        // cần thêm 1 pump() rỗng sau đó mới thấy `children` rỗng thật.
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();

        expect(game.children.whereType<SparkleParticle>(), isEmpty);
        expect(game.sparklePool.activeCount, 0);
        final createdAfterFirstBurst = game.sparklePool.totalCreated;

        // Burst thứ 2 phải tái sử dụng lại 4 particle vừa release, không
        // tạo thêm — đúng mục đích pooling.
        game.spawnSparkleBurst(Vector2(50, 50), count: 4);
        await tester.pump();

        expect(
          game.sparklePool.totalCreated,
          createdAfterFirstBurst,
          reason: 'burst thứ 2 phải tái sử dụng lại particle đã release, '
              'không tạo mới',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
