import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/puzzles.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/game_screen.dart';
import 'package:neon_jewels/presentation/screens/versus_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });

  tearDown(Get.reset);

  Widget appEn(Widget home) => GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('en', 'US'),
    fallbackLocale: AppTranslations.fallback,
    home: home,
  );

  Future<void> pumpNarrow(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(720, 1612);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(appEn(home));
    await tester.pump(const Duration(milliseconds: 180));

    expect(tester.takeException(), isNull);
  }

  final gameModes = <String, void Function(GameController)>{
    'Campaign': (g) => g.startLevel(1),
    'Ghost Replay': (g) => g.startGhostMode(1),
    'Daily Challenge': (g) => g.startDaily(),
    'Endless': (g) => g.startEndless(),
    'Boss': (g) => g.startBoss(1),
    'Color Rush': (g) => g.startColorRush(),
    'Gravity': (g) => g.startGravity(),
    'Zen': (g) => g.startZen(),
    'Rhythm': (g) => g.startRhythm(),
    'Soda': (g) => g.startSoda(),
    'Survival': (g) => g.startSurvival(),
    'Labyrinth': (g) => g.startLabyrinth(),
    'Puzzle': (g) => g.startPuzzle(kPuzzles.first),
    'Rush': (g) => g.startRush(),
  };

  for (final entry in gameModes.entries) {
    testWidgets('GameScreen smoke renders ${entry.key}', (tester) async {
      final g = Get.put(GameController());
      await tester.pump(const Duration(milliseconds: 30));

      entry.value(g);

      await pumpNarrow(tester, const GameScreen());
      expect(find.byType(GameScreen), findsOneWidget);
    });
  }

  testWidgets('Versus smoke renders 2 Players entry screen', (tester) async {
    await pumpNarrow(tester, const VersusScreen());

    expect(find.byType(VersusScreen), findsOneWidget);
    expect(find.text('2 PLAYERS'), findsOneWidget);
  });
}
