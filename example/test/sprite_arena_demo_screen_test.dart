import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roy_casual_kit_example/game/arena_actors.dart';
import 'package:roy_casual_kit_example/game/sprite_arena_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/energy_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit_example/screens/sprite_arena_demo_screen.dart';

class _ThrowingArena extends SpriteArenaGame {
  @override
  Future<void> onLoad() async {
    throw StateError('simulated load error');
  }
}

class _ControlledArena extends SpriteArenaGame {
  final loadGate = Completer<void>();

  @override
  Future<void> onLoad() async {
    await loadGate.future;
  }
}

Widget _wrap({
  SpriteArenaGame? game,
  Locale locale = AppTranslations.fallback,
  double textScale = 1,
}) => GetMaterialApp(
  translations: AppTranslations(),
  locale: locale,
  fallbackLocale: AppTranslations.fallback,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: SpriteArenaDemoScreen(game: game),
);

void main() {
  tearDown(Get.reset);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );
  });

  testWidgets('loading state locks gameplay and keeps Back available', (
    tester,
  ) async {
    final game = _ControlledArena();
    await tester.pumpWidget(_wrap(game: game));
    await tester.pump();
    expect(find.text('Loading arena…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Pause game'), findsNothing);
    expect(find.byType(GameJoystick), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    game.loadGate.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('error state shows friendly message and Back button', (
    tester,
  ) async {
    final game = _ThrowingArena();
    await tester.pumpWidget(_wrap(game: game));
    await tester.pump();
    expect(find.text('Could not load arena.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is CommonButton && w.label == 'Back'),
      findsOneWidget,
    );
    expect(find.byType(GameJoystick), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow controls do not overlap and help preserves manual pause',
    (tester) async {
      tester.view.physicalSize = const Size(240, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        rootBundle.evict('assets/tiles/character_arena.tmx');
        await tester.pumpWidget(_wrap());
        final game = tester
            .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
            .game!;
        await Future<void>.sync(
          game.toBeLoaded,
        ).timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      await tester.pump();
      final joystick = tester.getRect(find.byType(GameJoystick));
      final attack = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'sprite_arena_attack_semantics'.tr,
        ),
      );
      expect(joystick.overlaps(attack), isFalse);
      expect(attack.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byTooltip('Pause game'));
      await tester.pump();
      expect(find.text('Paused'), findsWidgets);
      await tester.tap(find.byTooltip('Controls'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Drag the joystick to move in eight directions.'),
        findsOneWidget,
      );
      final close = find.byWidgetPredicate(
        (w) => w is NeonDialogButton && w.action.label == 'OK',
      );
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pump(const Duration(milliseconds: 300));
      final game = tester
          .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
          .game!;
      expect(game.paused, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(240, 480),
    const Size(320, 568),
    const Size(400, 800),
    const Size(640, 320),
  ]) {
    testWidgets('Vietnamese large text and controls fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        rootBundle.evict('assets/tiles/character_arena.tmx');
        await tester.pumpWidget(
          _wrap(locale: const Locale('vi'), textScale: 2),
        );
        final game = tester
            .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
            .game!;
        await Future<void>.sync(
          game.toBeLoaded,
        ).timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      await tester.pump();
      final game = tester
          .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
          .game!;
      final attack = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Tấn công. Chạm để bắn, giữ để bắn liên tục.',
      );
      expect(
        tester
            .getRect(attack)
            .overlaps(tester.getRect(find.byType(GameJoystick))),
        isFalse,
      );
      expect(tester.getSize(attack).height, greaterThanOrEqualTo(48));
      await tester.tap(find.byTooltip('Điều khiển'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Kéo joystick để di chuyển 8 hướng.'), findsOneWidget);
      expect(game.paused, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(game.paused, isFalse);
      expect(find.text('Kéo joystick để di chuyển 8 hướng.'), findsNothing);
      await tester.tap(find.byTooltip('Tạm dừng trò chơi'));
      await tester.pump();
      final resume = find.byWidgetPredicate(
        (w) => w is CommonButton && w.label == 'Tiếp tục',
      );
      expect(tester.getSize(resume).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }

  for (final c in [
    (const Locale('en'), 'Score: 10'),
    (const Locale('vi'), 'Điểm: 10'),
  ]) {
    testWidgets('score chip follows the notifier in ${c.$1} at 240x480', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(240, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        rootBundle.evict('assets/tiles/character_arena.tmx');
        await tester.pumpWidget(_wrap(locale: c.$1, textScale: 2));
        final game = tester
            .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
            .game!;
        await Future<void>.sync(
          game.toBeLoaded,
        ).timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      await tester.pump();
      final game =
          tester
                  .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
                  .game!
              as SpriteArenaGame;
      game.score.value = 10;
      await tester.pump();
      expect(find.text(c.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in [
    (const Locale('en'), '4 lives, wave 1'),
    (const Locale('vi'), '4 mạng, đợt 1'),
  ]) {
    testWidgets('HUD semantics follow ${locale.$1}', (tester) async {
      final game = SpriteArenaGame();
      await tester.runAsync(() async {
        rootBundle.evict('assets/tiles/character_arena.tmx');
        await tester.pumpWidget(_wrap(game: game, locale: locale.$1));
        await Future<void>.sync(
          game.toBeLoaded,
        ).timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == locale.$2,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('small-screen HUD fits and terminal hides gameplay controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = SpriteArenaGame();
    await tester.runAsync(() async {
      rootBundle.evict('assets/tiles/character_arena.tmx');
      await tester.pumpWidget(_wrap(game: game, textScale: 2));
      await Future<void>.sync(
        game.toBeLoaded,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    await tester.pump();
    final status = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == '4 lives, wave 1',
    );
    final statusRect = tester.getRect(status);
    expect(statusRect.left, greaterThanOrEqualTo(0));
    expect(statusRect.right, lessThanOrEqualTo(240));
    expect(statusRect.top, greaterThan(48));
    game.lives.value = 0;
    game.roundOver.value = true;
    game.phase.value = ArenaPhase.gameOver;
    await tester.pump();
    expect(find.byType(GameJoystick), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is CommonButton && w.label == 'Attack'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pickup and Rapid Fire badges localize and countdown', (
    tester,
  ) async {
    final game = SpriteArenaGame();
    await tester.runAsync(() async {
      rootBundle.evict('assets/tiles/character_arena.tmx');
      await tester.pumpWidget(_wrap(game: game, locale: const Locale('vi')));
      await Future<void>.sync(
        game.toBeLoaded,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    await tester.pump();
    game.pickup = ArenaPickup(
      position: game.player!.position + Vector2(180, 0),
      kind: ArenaPickupKind.heal,
      onExpired: () {},
      onCollected: (_) {},
    );
    game.pickupRemaining.value = ArenaPickup.expirySeconds;
    game.rapidFireRemaining.value = 3.2;
    await tester.pump();
    expect(find.text('Hồi mạng'), findsOneWidget);
    expect(find.text('Nhanh 4 giây'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows lives and wave HUD, game over, and restarts', (
    tester,
  ) async {
    final game = SpriteArenaGame();
    await tester.runAsync(() async {
      rootBundle.evict('assets/tiles/character_arena.tmx');
      await tester.pumpWidget(_wrap(game: game));
      await Future<void>.sync(
        game.toBeLoaded,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Wave 1'), findsOneWidget);
    game.lives.value = 0;
    game.roundOver.value = true;
    game.phase.value = ArenaPhase.gameOver;
    await tester.pump();
    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('Score: 0  |  Wave: 1'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate((w) => w is CommonButton && w.label == 'Restart'),
    );
    await tester.pump();
    await tester.pump();
    expect(game.phase.value, ArenaPhase.playing);
    expect(game.lives.value, 4);
    expect(game.wave.value, 1);
    expect(game.score.value, 0);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Wave 1'), findsOneWidget);
    expect(find.text('Game Over'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows isolated full-screen Sprite Arena controls', (
    tester,
  ) async {
    await tester.runAsync(() async {
      rootBundle.evict('assets/tiles/character_arena.tmx');
      await tester.pumpWidget(_wrap());
      final game = tester
          .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
          .game!;
      await Future<void>.sync(
        game.toBeLoaded,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    await tester.pump();

    final game = tester
        .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
        .game!;
    expect(find.byType(GameJoystick), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'sprite_arena_attack_semantics'.tr,
      ),
      findsOneWidget,
    );
    expect(game.showClassicDemo, isFalse);
    expect(find.byType(EnergyBar), findsNothing);
    expect(
      tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == 'sprite_arena_attack_semantics'.tr,
            ),
          )
          .properties
          .onTap,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap fires once, hold repeats and release stops', (tester) async {
    final game = SpriteArenaGame();
    await tester.runAsync(() async {
      rootBundle.evict('assets/tiles/character_arena.tmx');
      await tester.pumpWidget(_wrap(game: game));
      await Future<void>.sync(
        game.toBeLoaded,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    await tester.pump();
    var shots = 0;
    game.player!.onAttack = () => shots++;
    final attack = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Attack. Tap to fire, hold to autofire.',
    );

    await tester.tap(attack);
    expect(shots, 1);
    final gesture = await tester.startGesture(tester.getCenter(attack));
    expect(shots, 2);
    await tester.pump(const Duration(milliseconds: 190));
    expect(shots, 2);
    await tester.pump(const Duration(milliseconds: 20));
    expect(shots, 3);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(shots, 3);

    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump();
    expect(game.isFiring, isFalse);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid-fire hold uses faster cadence; pointer cancel stops', (
    tester,
  ) async {
    final game = SpriteArenaGame();
    await tester.runAsync(() async {
      rootBundle.evict('assets/tiles/character_arena.tmx');
      await tester.pumpWidget(_wrap(game: game));
      await Future<void>.sync(
        game.toBeLoaded,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    await tester.pump();
    var shots = 0;
    game.player!.onAttack = () => shots++;
    game.rapidFireRemaining.value = 5;
    final attack = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Attack. Tap to fire, hold to autofire.',
    );
    final gesture = await tester.startGesture(tester.getCenter(attack));
    expect(shots, 1);
    await tester.pump(const Duration(milliseconds: 80));
    expect(shots, 2);
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(shots, 2);
    expect(game.isFiring, isFalse);

    final held = await tester.startGesture(tester.getCenter(attack));
    expect(game.isFiring, isTrue);
    await tester.tap(find.byTooltip('Controls'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.isFiring, isFalse);
    expect(game.paused, isTrue);
    await held.cancel();
    final close = find.byWidgetPredicate(
      (w) => w is NeonDialogButton && w.action.label == 'OK',
    );
    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.paused, isFalse);
    expect(tester.takeException(), isNull);
  });
}
