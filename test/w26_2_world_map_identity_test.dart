import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/world_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 26.2 — World Map identity: 10 màu + 10 landmark riêng biệt cho 10
/// thế giới, mount không crash ở mọi world.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('W26.2 — worldAccents đủ 10 màu riêng biệt', () {
    test('length == 10, không trùng màu giữa các world', () {
      expect(NeonTheme.worldAccents.length, 10);
      expect(NeonTheme.worldAccents.toSet().length, 10);
    });

    test('accentForWorld(1..10) không lặp lại', () {
      final colors = List.generate(10, (i) => NeonTheme.accentForWorld(i + 1));
      expect(colors.toSet().length, 10);
    });
  });

  group('W26.2 — landmark riêng theo world', () {
    test('worldLandmarks đủ 10, phủ hết enum WorldLandmark', () {
      expect(NeonTheme.worldLandmarks.length, 10);
      expect(
        NeonTheme.worldLandmarks.toSet().length,
        WorldLandmark.values.length,
      );
    });

    test('landmarkForWorld(1..10) khớp kWorlds theo thứ tự', () {
      for (final w in kWorlds) {
        expect(
          NeonTheme.landmarkForWorld(w.index),
          NeonTheme.worldLandmarks[w.index - 1],
        );
      }
    });
  });

  group('WorldMapScreen — mount từng world không crash', () {
    for (final w in kWorlds) {
      testWidgets('world ${w.index} (${w.name}) render OK', (tester) async {
        g.unlockedLevel.value = w.startLevel;
        await tester.pumpWidget(
          GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('vi', 'VN'),
            fallbackLocale: const Locale('en', 'US'),
            home: const WorldMapScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
