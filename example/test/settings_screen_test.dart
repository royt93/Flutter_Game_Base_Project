import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/list_tile_row.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toggle_switch.dart';
import 'package:roy_casual_kit_example/screens/home_screen.dart';
import 'package:roy_casual_kit_example/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression net for the base project's two screens. `NeonBg` (used by both)
/// runs a permanent `Ticker`, so `pumpAndSettle()` never returns here — use a
/// bounded `pump(duration)` instead (see CLAUDE.md's testing note).
Future<StorageService> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final store = StorageService(await SharedPreferences.getInstance());
  Get.put(store, permanent: true);
  Get.put(LocaleService(store), permanent: true);
  return store;
}

Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

void main() {
  tearDown(() {
    Get.reset();
    NeonTheme.dark = false;
    NeonTheme.colorBlindSafe = false;
  });

  group('HomeScreen', () {
    testWidgets('renders title and a Settings entry point', (tester) async {
      await _boot();

      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // StrokeText renders a stroke Text + a fill Text stacked, so both
      // titles match twice.
      expect(find.text('Roy Casual Kit Example'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsScreen without AudioManager registered', () {
    testWidgets('does not crash (regression: bare Obx on a null-guarded '
        'AudioManager throws "improper use of a GetX")', (tester) async {
      await _boot();
      expect(Get.isRegistered<AudioManager>(), isFalse);

      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      // Dark-mode and accessibility switches remain available without audio.
      expect(find.byType(CandyToggleSwitch), findsNWidgets(2));
      expect(find.widgetWithText(CommonListTile, 'Dark Mode'), findsOneWidget);
      // Language picker still renders fine on its own.
      expect(find.text('Language'), findsOneWidget);
    });
  });

  group('SettingsScreen with AudioManager registered', () {
    testWidgets('renders the sound switch and toggles mute', (tester) async {
      await _boot();
      final audio = Get.put(AudioManager(), permanent: true);
      expect(audio.muted.value, isFalse);

      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      final soundRow = find.widgetWithText(CommonListTile, 'Sound');
      expect(soundRow, findsOneWidget);
      final soundSwitch = find.descendant(
        of: soundRow,
        matching: find.byType(CandyToggleSwitch),
      );
      expect(tester.widget<CandyToggleSwitch>(soundSwitch).value, isTrue);

      await tester.tap(soundSwitch);
      await tester.pump(const Duration(milliseconds: 100));

      expect(audio.muted.value, isTrue);
      expect(tester.widget<CandyToggleSwitch>(soundSwitch).value, isFalse);
    });
  });

  group('SettingsScreen dark mode toggle', () {
    testWidgets(
      'toggling persists StorageKeys.themeDark and flips NeonTheme.dark',
      (tester) async {
        final store = await _boot();
        expect(NeonTheme.dark, isFalse);

        await tester.pumpWidget(_wrap(const SettingsScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        final darkRow = find.widgetWithText(CommonListTile, 'Dark Mode');
        final darkSwitch = find.descendant(
          of: darkRow,
          matching: find.byType(CandyToggleSwitch),
        );
        expect(tester.widget<CandyToggleSwitch>(darkSwitch).value, isFalse);

        await tester.tap(darkSwitch);
        await tester.pump(const Duration(milliseconds: 100));

        expect(NeonTheme.dark, isTrue);
        expect(store.getBool(StorageKeys.themeDark, def: false), isTrue);
        expect(tester.widget<CandyToggleSwitch>(darkSwitch).value, isTrue);
      },
    );
  });

  group('SettingsScreen color blind safe toggle', () {
    testWidgets('toggling persists and updates the gem palette', (
      tester,
    ) async {
      final store = await _boot();
      expect(NeonTheme.colorBlindSafe, isFalse);

      await tester.pumpWidget(_wrap(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final row = find.widgetWithText(CommonListTile, 'Color-blind Safe');
      final toggle = find.descendant(
        of: row,
        matching: find.byType(CandyToggleSwitch),
      );
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 100));

      expect(NeonTheme.colorBlindSafe, isTrue);
      expect(store.getBool(StorageKeys.colorBlindSafe), isTrue);
      expect(NeonTheme.gemColors, NeonTheme.colorBlindSafeGemColors);
    });
  });
}
