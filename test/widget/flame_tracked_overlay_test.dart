import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/flame_tracked_overlay.dart';

/// See CLAUDE.md's NeonBg testing gotcha: Flame's game loop runs a permanent
/// Ticker, same as RoyGame's own test (test/presentation/game/roy_game_test.dart)
/// — bounded `pump(duration)`, never `pumpAndSettle()`.
void main() {
  group('worldToScreenOffset', () {
    testWidgets('identity: topLeft-anchored, unzoomed, unpanned camera at zero '
        'gameWidgetTopLeft maps world position straight to screen position', (
      tester,
    ) async {
      final game = RoyGame();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(child: GameWidget(game: game)),
        ),
      );
      await game.toBeLoaded();
      await tester.pump();

      game.camera.viewfinder.anchor = Anchor.topLeft;
      game.camera.viewfinder.position = Vector2.zero();
      game.camera.viewfinder.zoom = 1;

      final result = worldToScreenOffset(
        camera: game.camera,
        worldPosition: Vector2(10, 20),
        gameWidgetTopLeft: Offset.zero,
      );

      expect(result, const Offset(10, 20));
    });

    testWidgets(
      'a non-zero gameWidgetTopLeft shifts the result by exactly that amount',
      (tester) async {
        final game = RoyGame();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(child: GameWidget(game: game)),
          ),
        );
        await game.toBeLoaded();
        await tester.pump();

        game.camera.viewfinder.anchor = Anchor.topLeft;
        game.camera.viewfinder.position = Vector2.zero();
        game.camera.viewfinder.zoom = 1;

        final result = worldToScreenOffset(
          camera: game.camera,
          worldPosition: Vector2(10, 20),
          gameWidgetTopLeft: const Offset(5, 7),
        );

        expect(result, const Offset(15, 27));
      },
    );
  });

  group('FlameTrackedOverlay', () {
    testWidgets(
      'renders its child at roughly the tracked entity\'s screen position',
      (tester) async {
        final game = RoyGame();
        final gameKey = GlobalKey();
        final childKey = UniqueKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GameWidget(key: gameKey, game: game),
                  ),
                  FlameTrackedOverlay(
                    game: game,
                    gameWidgetKey: gameKey,
                    worldPositionOf: () => game.circle.position,
                    child: SizedBox(
                      key: childKey,
                      width: 20,
                      height: 10,
                      child: ColoredBox(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await game.toBeLoaded();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));

        final gameTopLeft = tester.getTopLeft(find.byKey(gameKey));
        final expectedCenter = worldToScreenOffset(
          camera: game.camera,
          worldPosition: game.circle.position,
          gameWidgetTopLeft: gameTopLeft,
        );

        final actualCenter = tester.getCenter(find.byKey(childKey));

        expect((actualCenter - expectedCenter).distance, lessThan(1.0));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a non-center childAnchor lands the requested anchor point (not the '
      'top-left) on the tracked screen position',
      (tester) async {
        final game = RoyGame();
        final gameKey = GlobalKey();
        final childKey = UniqueKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GameWidget(key: gameKey, game: game),
                  ),
                  FlameTrackedOverlay(
                    game: game,
                    gameWidgetKey: gameKey,
                    worldPositionOf: () => game.circle.position,
                    childAnchor: Alignment.bottomCenter,
                    child: SizedBox(
                      key: childKey,
                      width: 20,
                      height: 10,
                      child: ColoredBox(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await game.toBeLoaded();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));

        final gameTopLeft = tester.getTopLeft(find.byKey(gameKey));
        final expectedPoint = worldToScreenOffset(
          camera: game.camera,
          worldPosition: game.circle.position,
          gameWidgetTopLeft: gameTopLeft,
        );

        final actualRect = tester.getRect(find.byKey(childKey));
        final actualBottomCenter = Offset(
          actualRect.center.dx,
          actualRect.bottom,
        );

        expect((actualBottomCenter - expectedPoint).distance, lessThan(1.0));
      },
    );

    testWidgets(
      // BUG-58: khi `Stack` chứa overlay này KHÔNG nằm ở gốc màn hình (0,0)
      // — ví dụ dưới 1 `Padding` (mô phỏng nằm dưới AppBar/SafeArea trong
      // 1 app thật) — `Positioned.left/top` cần toạ độ LOCAL tương đối với
      // `Stack`, không phải toạ độ GLOBAL màn hình. Test 2 case "roughly the
      // tracked entity's screen position" ở trên KHÔNG bắt được lỗi này vì
      // `Stack` của chúng nằm đúng gốc (0,0) — global == local trong trường
      // hợp đặc biệt đó. (Không dùng `Scaffold`/`AppBar` thật ở đây — probe
      // riêng xác nhận `Scaffold` làm GameWidget/Flame's `toBeLoaded()` mất
      // đồng bộ mount timing, một vấn đề hạ tầng test KHÔNG liên quan tới
      // bug toạ độ đang fix; `Padding` một mình đã đủ tạo offset khác 0 để
      // tái hiện đúng bug.)
      'Stack lệch gốc màn hình (dưới Padding) vẫn track đúng vị trí toàn '
      'cục, không cộng dồn lệch theo offset của Stack (BUG-58)',
      (tester) async {
        final game = RoyGame();
        final gameKey = GlobalKey();
        final childKey = UniqueKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Padding(
                padding: const EdgeInsets.only(left: 37, top: 53),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GameWidget(key: gameKey, game: game),
                    ),
                    FlameTrackedOverlay(
                      game: game,
                      gameWidgetKey: gameKey,
                      worldPositionOf: () => game.circle.position,
                      child: SizedBox(
                        key: childKey,
                        width: 20,
                        height: 10,
                        child: ColoredBox(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await game.toBeLoaded();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));

        // `getTopLeft`/`getCenter` của flutter_test luôn trả toạ độ GLOBAL
        // (màn hình) bất kể widget dùng Positioned local nào bên trong —
        // nên so sánh này đúng đắn bất kể `Stack` lệch gốc bao nhiêu, MIỄN
        // LÀ widget tính đúng toạ độ local. Code lỗi (dùng thẳng global làm
        // local) sẽ lệch actualCenter khỏi expectedCenter đúng bằng offset
        // của Stack (~37,53).
        final gameTopLeft = tester.getTopLeft(find.byKey(gameKey));
        final expectedCenter = worldToScreenOffset(
          camera: game.camera,
          worldPosition: game.circle.position,
          gameWidgetTopLeft: gameTopLeft,
        );

        final actualCenter = tester.getCenter(find.byKey(childKey));

        expect((actualCenter - expectedCenter).distance, lessThan(1.0));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'hides silently (no Positioned, no exception) when the GlobalKey was '
      'never attached to a GameWidget',
      (tester) async {
        final game = RoyGame();
        final unattachedKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Stack(
                children: [
                  FlameTrackedOverlay(
                    game: game,
                    gameWidgetKey: unattachedKey,
                    worldPositionOf: () => game.circle.position,
                    child: const Text('never shown'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 32));

        expect(
          find.descendant(
            of: find.byType(FlameTrackedOverlay),
            matching: find.byType(Positioned),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
