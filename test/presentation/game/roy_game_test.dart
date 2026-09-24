import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/game_event_bus.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';

/// Minimal smoke test proving `flame`'s FlameGame/Component/GameWidget wiring
/// actually works end-to-end in this package (see FEAT-14 — the dependency
/// was declared but never exercised). Not a real game, no need for the
/// `flame_test` harness: a plain `GameWidget` inside `Material` + a bounded
/// `pump()` is enough (avoid `pumpAndSettle()` — like `NeonBg`, Flame's game
/// loop runs a permanent `Ticker` that never settles).
///
/// IDEA-65: `game.toBeLoaded()` + a SINGLE `tester.pump()` isn't always
/// enough once a component's own `onLoad` adds a child (e.g. `TappableCircle`/
/// `BouncingOrb`'s hitboxes) — that child's own mount finishes on the frame
/// AFTER the one that flushed `toBeLoaded()`. A second pump reliably settles
/// it; this helper keeps that 1-time discovery from becoming 13 copies of
/// the same 2-line fix.
Future<void> _settled(WidgetTester tester, RoyGame game) async {
  await game.toBeLoaded();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('builds inside a GameWidget without throwing', (tester) async {
    final game = RoyGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: GameWidget(game: game)),
      ),
    );
    await _settled(tester, game);

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the circle toggles its tapped state', (tester) async {
    final game = RoyGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: GameWidget(game: game)),
      ),
    );
    await _settled(tester, game);

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
      await _settled(tester, game);

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
        await _settled(tester, game);

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
      await _settled(tester, game);

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
        await _settled(tester, game);

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

  group('IDEA-65: BouncingOrb (collision detection demo)', () {
    testWidgets('orb được thêm vào component tree khi load xong', (
      tester,
    ) async {
      final game = RoyGame();
      await tester.pumpWidget(
        MaterialApp(home: Material(child: GameWidget(game: game))),
      );
      await _settled(tester, game);

      expect(game.children.whereType<BouncingOrb>().length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'orb di chuyển theo velocity mỗi frame (update thật sự chạy)',
      (tester) async {
        final game = RoyGame();
        await tester.pumpWidget(
          MaterialApp(home: Material(child: GameWidget(game: game))),
        );
        await _settled(tester, game);

        final before = game.orb.position.clone();
        await tester.pump(const Duration(milliseconds: 100));

        expect(game.orb.position, isNot(equals(before)));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('orb bật ngược lại khi chạm mép trái màn hình', (
      tester,
    ) async {
      final game = RoyGame();
      await tester.pumpWidget(
        MaterialApp(home: Material(child: GameWidget(game: game))),
      );
      await _settled(tester, game);

      game.orb
        ..position = Vector2(game.orb.radius, 100)
        ..velocity = Vector2(-90, 0);

      game.update(0.05);

      expect(game.orb.velocity.x, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'orb chạm TappableCircle -> cả 2 component đổi màu vàng '
      '(CollisionCallbacks thật sự bắt được va chạm qua GameWidget)',
      (tester) async {
        final game = RoyGame();
        await tester.pumpWidget(
          MaterialApp(home: Material(child: GameWidget(game: game))),
        );
        await _settled(tester, game);

        // Đặt orb lệch tâm circle đúng 30px — nằm giữa |40-16|=24 (orb
        // NẰM HẲN TRONG circle, 2 vòng tròn không cắt nhau ở biên nào cả
        // — Flame's circle-circle intersections() trả về RỖNG cho case
        // containment thuần, dù 2 hình dạng rõ ràng chồng lấn) và
        // 40+16=56 (tách rời hoàn toàn) — đúng vùng biên 2 vòng tròn THẬT
        // SỰ cắt nhau, nơi Flame's collision engine phát hiện được.
        game.orb.position = game.circle.position + Vector2(30, 0);
        game.orb.velocity = Vector2.zero();

        for (var i = 0; i < 3; i++) {
          game.update(0.016);
        }
        await tester.pump();

        // toARGB32(), not raw Color equality: comparing Color objects
        // directly here is flaky — a value round-tripped through a real
        // render pass (this test does several via _settled/update/pump)
        // can differ by float epsilon from the same-looking source
        // constant despite printing identically at 4-decimal precision.
        expect(game.orb.paint.color.toARGB32(), NeonTheme.gold.toARGB32());
        expect(game.circle.paint.color.toARGB32(), NeonTheme.gold.toARGB32());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('không va chạm -> circle vẫn giữ màu tap-toggle bình thường', (
      tester,
    ) async {
      final game = RoyGame();
      await tester.pumpWidget(
        MaterialApp(home: Material(child: GameWidget(game: game))),
      );
      await _settled(tester, game);

      // Đưa orb ra xa hẳn circle để chắc chắn không giao hitbox.
      game.orb.position = Vector2(-1000, -1000);
      game.orb.velocity = Vector2.zero();

      await tester.pump(const Duration(milliseconds: 50));

      expect(game.circle.paint.color.toARGB32(), NeonTheme.cyan.toARGB32());
      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-88: GameEventBus (optional, non-breaking)', () {
    testWidgets(
      'RoyGame() không truyền eventBus -> tap vẫn hoạt động bình thường, '
      'không throw',
      (tester) async {
        final game = RoyGame();
        await tester.pumpWidget(
          MaterialApp(home: Material(child: GameWidget(game: game))),
        );
        await _settled(tester, game);

        await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tap circle emit đúng CircleTappedEvent qua eventBus khi có truyền vào',
      (tester) async {
        final bus = GameEventBus();
        final received = <CircleTappedEvent>[];
        bus.subscribe<CircleTappedEvent>(received.add);
        final game = RoyGame(eventBus: bus);

        await tester.pumpWidget(
          MaterialApp(home: Material(child: GameWidget(game: game))),
        );
        await _settled(tester, game);

        await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
        await tester.pump(const Duration(milliseconds: 100));

        expect(received, hasLength(1));
        expect(tester.takeException(), isNull);
        await bus.dispose();
      },
    );
  });
}
