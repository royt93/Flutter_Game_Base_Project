import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final attack = tester.getRect(find.byType(CommonButton));
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
        (w) => w is CommonButton && w.label == 'Đánh',
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
        (widget) => widget is CommonButton && widget.label == 'Attack',
      ),
      findsOneWidget,
    );
    expect(game.showClassicDemo, isFalse);
    expect(find.byType(EnergyBar), findsNothing);
    expect(
      tester
          .widget<CommonButton>(
            find.byWidgetPredicate(
              (widget) => widget is CommonButton && widget.label == 'Attack',
            ),
          )
          .onTap,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('joystick moves sprite and Attack triggers action', (
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
    final game =
        tester
                .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
                .game!
            as SpriteArenaGame;
    final player = game.player!;
    final startX = player.position.x;
    final joystick = tester.widget<GameJoystick>(find.byType(GameJoystick));
    joystick.onDirectionChanged(
      GameJoystickDirection.right,
      const Offset(1, 0),
    );
    player.update(0.1);
    expect(player.position.x, greaterThan(startX));

    Finder attackBtn() => find.byWidgetPredicate(
      (widget) => widget is CommonButton && widget.label == 'Attack',
    );

    expect(player.isAttacking, isFalse);
    final attack = tester.widget<CommonButton>(attackBtn()).onTap!;
    attack();
    expect(player.isAttacking, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(player.isAttacking, isFalse);
    final pause = find.byTooltip('Pause game');
    await tester.tap(pause);
    await tester.pump();
    expect(game.attackEnabled, isFalse);
    expect(tester.widget<CommonButton>(attackBtn()).onTap, isNull);
    attack();
    expect(player.isAttacking, isFalse);
    final resumeFab = find.byType(FloatingActionButton);
    await tester.tap(resumeFab);
    await tester.pump();
    expect(tester.widget<CommonButton>(attackBtn()).onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
