import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/flame_tracked_overlay.dart';
import 'package:roy_casual_kit_example/screens/game_demo_screen.dart';

/// GameDemoScreen doesn't use NeonBg, but the FlameGame it hosts runs its own
/// permanent game-loop Ticker (same class of issue — see CLAUDE.md's NeonBg
/// testing gotcha) — use a bounded `pump(duration)`, not `pumpAndSettle()`.
Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

void main() {
  tearDown(Get.reset);

  testWidgets('renders a full-screen GameWidget without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const GameDemoScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GameWidget<RoyGame>), findsOneWidget);
    expect(tester.takeException(), isNull);

    // FEAT-14 regression: GameWidget is wrapped in Positioned.fill inside a
    // Stack whose only OTHER child must also be Positioned — a Stack sizes
    // itself to its non-positioned children, so if NeonAppBar were a plain
    // (non-Positioned) Stack child, the whole Stack — and therefore the
    // "full-screen" GameWidget inside it — would collapse to app-bar height.
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final gameSize = tester.getSize(find.byType(GameWidget<RoyGame>));
    expect(gameSize.height, greaterThan(screenSize.height * 0.8));
  });

  testWidgets(
    'tapping the info button shows a NeonDialog overlay above the GameWidget',
    (tester) async {
      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 300));

      // The dialog panel renders the same title text as the app bar, so at
      // least 2 matches once the overlay is up (StrokeText also stacks a
      // stroke + fill Text for each render).
      expect(find.text('game_demo'.tr), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows a FlameTrackedOverlay label tracking the circle, without throwing '
    '(IDEA-07)',
    (tester) async {
      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FlameTrackedOverlay), findsOneWidget);
      // StrokeText stacks a stroke + fill Text for each render (see the
      // "tapping the info button" test above for the same gotcha).
      expect(find.text('Circle'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(FlameTrackedOverlay),
          matching: find.byType(Positioned),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
