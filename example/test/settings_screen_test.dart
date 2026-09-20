import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/pseudo_locale.dart';
import 'package:roy_casual_kit/presentation/widgets/common/list_tile_row.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toggle_switch.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_button.dart';
import 'package:roy_casual_kit_example/screens/game_demo_screen.dart';
import 'package:roy_casual_kit_example/screens/home_screen.dart';
import 'package:roy_casual_kit_example/screens/settings_screen.dart';
import 'package:roy_casual_kit_example/screens/widget_showcase_screen.dart';
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

    group('ENH-54: navigation', () {
      testWidgets('tap "Settings" → điều hướng thật sang SettingsScreen', (
        tester,
      ) async {
        await _boot();

        await tester.pumpWidget(_wrap(const HomeScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.widgetWithText(NeonButton, 'Settings').first);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Get.to() pushes SettingsScreen on top — HomeScreen stays mounted
        // underneath (standard Navigator back-stack behavior, not a bug),
        // so this only asserts the NEW screen actually arrived.
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'tap "Widget Kit" → điều hướng thật sang WidgetShowcaseScreen',
        (tester) async {
          await _boot();

          await tester.pumpWidget(_wrap(const HomeScreen()));
          await tester.pump(const Duration(milliseconds: 100));

          await tester.tap(find.widgetWithText(NeonButton, 'Widget Kit').first);
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }

          expect(find.byType(WidgetShowcaseScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('tap "Flame Demo" → điều hướng thật sang GameDemoScreen', (
        tester,
      ) async {
        await _boot();

        await tester.pumpWidget(_wrap(const HomeScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.widgetWithText(NeonButton, 'Flame Demo').first);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(GameDemoScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
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
      // Dark-mode, accessibility, and pseudo-locale (FEAT-79, always
      // visible under kDebugMode which flutter test always runs as)
      // switches remain available without audio.
      expect(find.byType(CandyToggleSwitch), findsNWidgets(3));
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

  group('ENH-54: _pickLanguage', () {
    // The sheet's slide-up entrance animation lands its rows far enough
    // down that a real screen tap can't reliably land on them within a
    // bounded pump (verified empirically — its AnimationController only
    // starts ticking on its own first frame, so timing it exactly via
    // pump(duration) races with NeonBg's already-running permanent Ticker
    // on the screen underneath). Invoking the row's own `onTap` directly
    // exercises the exact same production callback `_pickLanguage` wires
    // up, without depending on the sheet's transition having visually
    // settled at a precise pixel position.
    Future<void> tapLocaleRow(WidgetTester tester, String languageCode) async {
      final tile = tester.widget<CommonListTile>(
        find.widgetWithText(CommonListTile, languageCode).last,
      );
      tile.onTap!();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
      'tap Language row mở bottom sheet, chọn locale khác → LocaleService.current đổi đúng và subtitle cập nhật',
      (tester) async {
        final store = await _boot();
        final localeService = Get.find<LocaleService>();
        expect(localeService.current.value.languageCode, 'en');

        await tester.pumpWidget(_wrap(const SettingsScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('EN'), findsOneWidget);

        await tester.tap(find.widgetWithText(CommonListTile, 'Language'));
        await tester.pump(const Duration(milliseconds: 100));

        // Bottom sheet lists 1 CommonListTile per supported locale (EN, VI)
        // — the current one (EN) is checked, VI isn't yet.
        expect(find.widgetWithText(CommonListTile, 'VI'), findsOneWidget);

        await tapLocaleRow(tester, 'VI');

        expect(localeService.current.value.languageCode, 'vi');
        expect(
          store.getString(StorageKeys.localeCode),
          AppTranslations.codeOf(const Locale('vi')),
        );
        // Sheet closed, subtitle back on SettingsScreen now reads VI.
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('VI'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'chọn lại đúng locale hiện tại (EN) → không đổi gì, sheet vẫn đóng bình thường',
      (tester) async {
        final store = await _boot();
        final localeService = Get.find<LocaleService>();

        await tester.pumpWidget(_wrap(const SettingsScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.widgetWithText(CommonListTile, 'Language'));
        await tester.pump(const Duration(milliseconds: 100));

        await tapLocaleRow(tester, 'EN');

        expect(localeService.current.value.languageCode, 'en');
        expect(
          store.getString(StorageKeys.localeCode),
          AppTranslations.codeOf(const Locale('en')),
        );
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
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

  group('FEAT-79: Pseudo-locale (QA) toggle', () {
    testWidgets(
      'bật toggle -> title đổi sang bản pseudo-localize; tắt lại -> về tiếng Anh gốc',
      (tester) async {
        await _boot();
        await tester.pumpWidget(_wrap(const SettingsScreen()));
        await tester.pump(const Duration(milliseconds: 100));

        // NeonAppBar's title renders via StrokeText — a stroke layer +
        // fill layer, each its own Text widget with identical text, so
        // any assertion here uses findsWidgets (>=1) not findsOneWidget.
        expect(find.text('Settings'), findsWidgets);

        final row = find.widgetWithText(CommonListTile, 'Pseudo-locale (QA)');
        expect(row, findsOneWidget);
        // Invoking onChanged directly (not tester.tap) — same workaround
        // as `tapLocaleRow` above: Get.updateLocale ultimately calls
        // GetX's forceAppUpdate/performReassemble, which conflicts with
        // Flutter test's scheduler-phase assertion when triggered from
        // inside a real simulated gesture's frame.
        CandyToggleSwitch toggleWidget() =>
            tester.widget<CandyToggleSwitch>(
              find.descendant(of: row, matching: find.byType(CandyToggleSwitch)),
            );

        toggleWidget().onChanged!(true);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(pseudoLocalize('Settings')), findsWidgets);
        expect(find.text('Settings'), findsNothing);
        expect(tester.takeException(), isNull);

        toggleWidget().onChanged!(false);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Settings'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
