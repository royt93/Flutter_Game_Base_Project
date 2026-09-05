import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_base_game/core/app_translations.dart';
import 'package:roy_base_game/core/audio_manager.dart';
import 'package:roy_base_game/core/locale_service.dart';
import 'package:roy_base_game/core/storage_service.dart';
import 'package:roy_base_game/presentation/screens/home_screen.dart';
import 'package:roy_base_game/presentation/screens/settings_screen.dart';
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
  tearDown(Get.reset);

  group('HomeScreen', () {
    testWidgets('renders title and a Settings entry point', (tester) async {
      await _boot();

      await tester.pumpWidget(_wrap(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // StrokeText renders a stroke Text + a fill Text stacked, so both
      // titles match twice.
      expect(find.text('Roy Project Base Game'), findsWidgets);
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
      // No audio switch to show when AudioManager isn't registered.
      expect(find.byType(SwitchListTile), findsNothing);
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
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump(const Duration(milliseconds: 100));

      expect(audio.muted.value, isTrue);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    });
  });
}
