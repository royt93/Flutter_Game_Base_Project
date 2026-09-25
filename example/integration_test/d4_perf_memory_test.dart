import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/confetti_overlay.dart';
import 'package:roy_casual_kit_example/screens/game_demo_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _button(String label) => find.widgetWithText(CommonButton, label);

Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    Get.put(
      StorageService(await SharedPreferences.getInstance()),
      permanent: true,
    );
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'D4 device proof: repaint boundaries + achievement confetti + memory trim + lifecycle resume',
    (tester) async {
      var memoryTrimCount = 0;
      final lifecycle = RoyLifecycleCoordinator(
        trimMemoryOnBackground: true,
        onTrimMemory: () => memoryTrimCount++,
      );
      Get.put(lifecycle, permanent: true);
      Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
      Get.put(AchievementService(), permanent: true);

      await tester.pumpWidget(_wrap(const GameDemoScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(GameWidget<RoyGame>), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(4));
      expect(find.byType(ConfettiOverlay), findsNothing);
      expect(find.textContaining('gems: 0'), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.tapAt(tester.getCenter(find.byType(GameWidget<RoyGame>)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ConfettiOverlay), findsOneWidget);
      expect(find.textContaining('gems: 20'), findsOneWidget);
      expect(find.textContaining('tap: 10/10'), findsOneWidget);

      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(memoryTrimCount, 1);
      expect(_button('Resume'), findsWidgets);

      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_button('Resume'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
