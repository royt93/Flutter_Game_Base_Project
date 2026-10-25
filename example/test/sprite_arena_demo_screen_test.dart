import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/energy_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit_example/screens/sprite_arena_demo_screen.dart';

Widget _wrap() => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: const SpriteArenaDemoScreen(),
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

  testWidgets('shows isolated full-screen Sprite Arena controls', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 100));

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
    expect(tester.takeException(), isNull);
  });

  testWidgets('joystick moves sprite and Attack triggers action', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 100));

    final game = tester
        .widget<GameWidget<RoyGame>>(find.byType(GameWidget<RoyGame>))
        .game!;
    final player = game.player!;
    final startX = player.position.x;
    final joystick = tester.widget<GameJoystick>(find.byType(GameJoystick));
    joystick.onDirectionChanged(
      GameJoystickDirection.right,
      const Offset(1, 0),
    );
    player.update(0.1);
    expect(player.position.x, greaterThan(startX));

    expect(player.isAttacking, isFalse);
    tester.widget<CommonButton>(find.byType(CommonButton)).onTap!();
    expect(player.isAttacking, isTrue);
    expect(tester.takeException(), isNull);
  });
}
