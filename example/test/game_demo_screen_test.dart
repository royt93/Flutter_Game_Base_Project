import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/flame_tracked_overlay.dart';
import 'package:roy_casual_kit_example/screens/game_demo_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CommonButton vẽ label qua StrokeText (2 lớp Text chồng nhau) — dùng finder
// theo CommonButton thay vì find.text trực tiếp (cùng lý do
// common_button_test.dart / pause_overlay_test.dart).
Finder _button(String label) => find.widgetWithText(CommonButton, label);

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

  setUp(() async {
    // FEAT-88: GameDemoScreen now wires EconomyWallet (via
    // `StorageService.to`) and AchievementService as GameEventBus
    // subscribers — needs StorageService registered before pumping.
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );
  });

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

      // FEAT-53: 2 FAB giờ (pause + info) — nhắm đúng info bằng icon.
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump(const Duration(milliseconds: 300));

      // The dialog panel renders the same title text as the app bar, so at
      // least 2 matches once the overlay is up (StrokeText also stacks a
      // stroke + fill Text for each render).
      expect(find.text('game_demo'.tr), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-53: pause FAB shows PauseOverlay above the GameWidget, Resume hides it',
    (tester) async {
      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(_button('Resume'), findsNothing);

      await tester.tap(find.byIcon(Icons.pause));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(_button('Resume'), findsWidgets);
      expect(_button('Restart'), findsWidgets);

      await tester.tap(_button('Resume').first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(_button('Resume'), findsNothing);
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

  group('FEAT-88: GameEventBus wires 1 tap to 2 independent services', () {
    testWidgets(
      'tap circle -> EconomyWallet (gems) VÀ AchievementService (tap '
      'progress) đều cập nhật, cả 2 hiện trên badge',
      (tester) async {
        await tester.pumpWidget(_wrap(const GameDemoScreen()));
        await tester.pump(const Duration(milliseconds: 100));
        // IDEA-65: RoyGame's TappableCircle now adds its own hitbox child
        // in onLoad — that child's mount settles 1 Flutter frame after the
        // one the pump above flushed, and a tap dispatched before it fully
        // settles is simply missed (not deferred/retried). 1 extra bare
        // pump() reliably closes that gap.
        await tester.pump();

        expect(find.textContaining('gems: 0'), findsOneWidget);
        expect(find.textContaining('tap: 0/10'), findsOneWidget);

        await tester.tapAt(
          tester.getCenter(find.byType(GameWidget<RoyGame>)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('gems: 1'), findsOneWidget);
        expect(find.textContaining('tap: 1/10'), findsOneWidget);

        final wallet = EconomyWallet.maybe!;
        final achievements = AchievementService.maybe!;
        expect(wallet.balanceOf('gems'), 1);
        expect(achievements.progressOf('game_demo_circle_tap_master'), 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'nhiều tap liên tiếp cộng dồn đúng cả 2 phía, không mất event nào',
      (tester) async {
        await tester.pumpWidget(_wrap(const GameDemoScreen()));
        await tester.pump(const Duration(milliseconds: 100));
        // IDEA-65: see the sibling test above for why this extra pump is
        // needed before the first tap can land.
        await tester.pump();

        for (var i = 0; i < 3; i++) {
          await tester.tapAt(
            tester.getCenter(find.byType(GameWidget<RoyGame>)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.textContaining('gems: 3'), findsOneWidget);
        expect(find.textContaining('tap: 3/10'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ENH-82: GameSessionController synced with RoyLifecycleCoordinator', () {
    testWidgets(
      'app bị background thật (OS lifecycle) trong lúc playing -> '
      'PauseOverlay tự hiện đúng panel (không cần bấm FAB); foreground lại '
      '-> tự ẩn',
      (tester) async {
        final lifecycle = RoyLifecycleCoordinator();
        Get.put(lifecycle, permanent: true);

        await tester.pumpWidget(_wrap(const GameDemoScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        expect(_button('Resume'), findsNothing);

        // Drives the coordinator's own `didChangeAppLifecycleState`
        // directly (same as test/core/game_session_controller_test.dart's
        // own lifecycle-bridge unit test) rather than
        // `tester.binding.handleAppLifecycleStateChanged` — the latter
        // dispatches to EVERY `WidgetsBindingObserver` registered in this
        // test's zone (including ones from other services this screen
        // pulls in, e.g. `AudioManager`/`PerformanceTierService`), one of
        // which hung the test indefinitely; calling the coordinator
        // directly exercises the exact same `RoyLifecycleCoordinator` ->
        // `GameSessionController` hook path this screen actually wires up,
        // without that unrelated interference.
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          _button('Resume'),
          findsWidgets,
          reason:
              'showForSystemPause: true nên panel phải tự hiện khi '
              'background, không cần người chơi bấm FAB pause',
        );

        // Foreground lại -> tự resume, panel tự ẩn.
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(_button('Resume'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'không có RoyLifecycleCoordinator đăng ký -> demo vẫn hoạt động bình '
      'thường, không crash (lifecycle: null, giống hành vi trước ENH-82)',
      (tester) async {
        expect(Get.isRegistered<RoyLifecycleCoordinator>(), isFalse);

        await tester.pumpWidget(_wrap(const GameDemoScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        expect(_button('Resume'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
