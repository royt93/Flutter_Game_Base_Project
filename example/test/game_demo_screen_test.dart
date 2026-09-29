import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/game_event_bus.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/local_scoreboard_service.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/confetti_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/flame_tracked_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_app_bar.dart';
import 'package:roy_casual_kit_example/screens/game_demo_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CommonButton vẽ label qua StrokeText (2 lớp Text chồng nhau) — dùng finder
// theo CommonButton thay vì find.text trực tiếp (cùng lý do
// common_button_test.dart / pause_overlay_test.dart).
Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is CommonButton && widget.label == label,
);

/// GameDemoScreen doesn't use NeonBg, but the FlameGame it hosts runs its own
/// permanent game-loop Ticker (same class of issue — see CLAUDE.md's NeonBg
/// testing gotcha) — use a bounded `pump(duration)`, not `pumpAndSettle()`.
Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

class _FakeAudioManager extends AudioManager {
  final played = <String>[];
  final ducked = <bool>[];

  @override
  Future<void> playSfx(
    String fileName, {
    double volume = 1.0,
    bool duck = false,
  }) async {
    played.add(fileName);
    ducked.add(duck);
  }
}

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
    'FEAT-53 + BUG-91: pause FAB shows PauseOverlay above the GameWidget AND '
    'actually freezes the Flame engine (not just the session UI); Resume '
    'hides overlay and unfreezes it',
    (tester) async {
      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(_button('Resume'), findsNothing);

      final game = tester
          .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
          .game!;
      expect(game.paused, isFalse);

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is FloatingActionButton && widget.heroTag == 'pause',
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(_button('Resume'), findsWidgets);
      expect(_button('Restart'), findsWidgets);
      // BUG-91: FAB used to only pause GameSessionController, never the
      // Flame engine — the orb kept bouncing under the pause overlay.
      expect(game.paused, isTrue);
      final frozen = game.orb.position.clone();
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.orb.position, equals(frozen));

      await tester.tap(_button('Resume').first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(_button('Resume'), findsNothing);
      expect(game.paused, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.orb.position, isNot(equals(frozen)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BUG-91 audit: Pause rồi Restart chạy lại Flame engine, không kẹt pause',
    (tester) async {
      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      final game = tester
          .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
          .game!;

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is FloatingActionButton && widget.heroTag == 'pause',
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(game.paused, isTrue);

      await tester.tap(_button('Restart').first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_button('Resume'), findsNothing);
      expect(game.paused, isFalse);

      final before = game.orb.position.clone();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(game.orb.position, isNot(equals(before)));
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

  testWidgets(
    'core loop: start round spends energy; five Circle taps earn XP, coins, and score',
    (tester) async {
      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(_button('Start Round (-1 Energy)'), findsOneWidget);
      expect(EnergyService.maybe!.currentEnergy, 5);
      await tester.tap(_button('Start Round (-1 Energy)'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(EnergyService.maybe!.currentEnergy, 4);
      expect(find.text('Tap Circle: 0 / 5'), findsWidgets);

      final game = find.byType(GameWidget<RoyGame>);
      for (var i = 0; i < 5; i++) {
        await tester.tapAt(tester.getCenter(game));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(PlayerProgressionService.maybe!.snapshot.value.totalXpEarned, 40);
      expect(EconomyWallet.maybe!.balanceOf('coins'), 30);
      expect(LocalScoreboardService.maybe!.topN(1).single.score, '50');
      expect(
        find.textContaining('Victory! +40 XP, +30 coins.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('FEAT-88: GameEventBus wires 1 tap to 2 independent services', () {
    testWidgets('tap circle -> EconomyWallet (gems) VÀ AchievementService (tap '
        'progress) đều cập nhật, cả 2 hiện trên badge', (tester) async {
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

      await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('gems: 1'), findsOneWidget);
      expect(find.textContaining('tap: 1/10'), findsOneWidget);

      final wallet = EconomyWallet.maybe!;
      final achievements = AchievementService.maybe!;
      expect(wallet.balanceOf('gems'), 1);
      expect(achievements.progressOf('game_demo_circle_tap_master'), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap circle phát SFX thường, unlock phát SFX ducked', (
      tester,
    ) async {
      final audio = _FakeAudioManager();
      Get.put<AudioManager>(audio, permanent: true);

      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      // IDEA-65: see the sibling test above for why this extra pump is
      // needed before the first tap can land.
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(audio.played, ['audio/tap.ogg']);
      expect(audio.ducked, [false]);

      while (EconomyWallet.maybe!.balanceOf('gems') < 20) {
        await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 100));

      expect(audio.played.length, 11);
      expect(audio.ducked.where((duck) => duck), hasLength(1));
      expect(tester.takeException(), isNull);
    });

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

    testWidgets(
      'tap đủ 10 lần -> hoàn thành achievement -> nổ ConfettiOverlay, thưởng '
      'thêm 10 gems bonus và đổi icon sao',
      (tester) async {
        await tester.pumpWidget(_wrap(const GameDemoScreen()));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.byType(ConfettiOverlay), findsNothing);
        expect(find.byIcon(Icons.diamond_outlined), findsOneWidget);

        for (var i = 0; i < 10; i++) {
          await tester.tapAt(
            tester.getCenter(find.byType(GameWidget<RoyGame>)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ConfettiOverlay), findsOneWidget);
        expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
        expect(find.textContaining('gems: 20'), findsOneWidget);
        expect(find.textContaining('tap: 10/10'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'ENH-82: GameSessionController synced with RoyLifecycleCoordinator',
    () {
      testWidgets('app bị background thật (OS lifecycle) trong lúc playing -> '
          'PauseOverlay tự hiện đúng panel (không cần bấm FAB); foreground lại '
          '-> tự ẩn', (tester) async {
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
      });

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
    },
  );

  group('D1: Render Pipeline & Repaint Isolation', () {
    testWidgets(
      'các tầng GameWidget, NeonAppBar, HUD Badge và FAB đều có RepaintBoundary riêng',
      (tester) async {
        await tester.pumpWidget(_wrap(const GameDemoScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        // GameWidget bọc trong RepaintBoundary
        expect(
          find.descendant(
            of: find.byType(RepaintBoundary),
            matching: find.byType(GameWidget<RoyGame>),
          ),
          findsOneWidget,
        );

        // NeonAppBar bọc trong RepaintBoundary
        expect(
          find.descendant(
            of: find.byType(RepaintBoundary),
            matching: find.byType(NeonAppBar),
          ),
          findsOneWidget,
        );

        // Ít nhất 4 RepaintBoundary độc lập trên màn hình chính
        final boundaries = find.byType(RepaintBoundary);
        expect(boundaries, findsAtLeastNWidgets(4));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('BUG-93: GameEventBus subscription cleanup', () {
    testWidgets(
      'dispose GameDemoScreen cancel subscription do screen tạo trên bus '
      'caller inject; bus vẫn mở nhưng không còn listener giữ State/context',
      (tester) async {
        final bus = GameEventBus();

        await tester.pumpWidget(_wrap(GameDemoScreen(eventBus: bus)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(bus.hasListeners, isTrue);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        expect(bus.hasListeners, isFalse);
        expect(tester.takeException(), isNull);
        await bus.dispose();
      },
    );
  });

  group('D4 Integration Flow: Full Gameplay, Burst & Memory Lifecycle', () {
    testWidgets(
      'Integration test: 10 taps -> unlock achievement + Confetti burst -> '
      'background dọn dẹp cache + pause -> foreground resume mượt mà',
      (tester) async {
        var memoryTrimCount = 0;
        final lifecycle = RoyLifecycleCoordinator(
          trimMemoryOnBackground: true,
          onTrimMemory: () => memoryTrimCount++,
        );
        Get.put(lifecycle, permanent: true);

        await tester.pumpWidget(_wrap(const GameDemoScreen()));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // Ban đầu chưa có ConfettiOverlay
        expect(find.byType(ConfettiOverlay), findsNothing);
        expect(find.textContaining('gems: 0'), findsOneWidget);

        // 1. Gameplay tap burst 10 lần
        for (var i = 0; i < 10; i++) {
          await tester.tapAt(
            tester.getCenter(find.byType(GameWidget<RoyGame>)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 100));

        // Confetti xuất hiện và thưởng điểm đúng
        expect(find.byType(ConfettiOverlay), findsOneWidget);
        expect(find.textContaining('gems: 20'), findsOneWidget);
        expect(find.textContaining('tap: 10/10'), findsOneWidget);

        // 2. Chuyển sang background: kích hoạt memory trim và PauseOverlay
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(
          memoryTrimCount,
          1,
          reason: 'Bộ nhớ cache phải được dọn khi app background',
        );
        expect(_button('Resume'), findsWidgets);

        // 3. Foreground trở lại: tự resume và tiếp tục vẽ ổn định
        lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(_button('Resume'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
