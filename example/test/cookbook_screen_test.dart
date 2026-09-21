import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit_example/screens/cookbook_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `NeonBg` (used by [CookbookScreen]) runs a permanent `Ticker`, so
/// `pumpAndSettle()` never returns here — use a bounded `pump(duration)`
/// instead (see CLAUDE.md's testing note).
Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final store = StorageService(await SharedPreferences.getInstance());
  Get.put(store, permanent: true);
  Get.put(LocaleService(store), permanent: true);
}

Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

/// The screen is one long `ListView` of category `PanelCard`s — a tile a
/// few sections down can exist in the element tree (`ListView`'s
/// `cacheExtent` pre-builds just past the viewport) while still being
/// visually off-screen, where `tester.tap()` only warns and silently
/// misses. `scrollUntilVisible` checks real on-screen visibility, not just
/// tree presence, so every lookup below goes through it.
Future<void> _scrollUntilVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 250, scrollable: find.byType(Scrollable).first);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Scrolls to and taps [label]'s button, settling just past the
/// `ToastBanner` entrance animation (~220ms) so its text is assertable —
/// but well before its 2s auto-dismiss timer fires. Call [_flushToast]
/// after the assertion to drain that timer before the test ends, or
/// `TestWidgetsFlutterBinding`'s teardown asserts "Timer still pending".
Future<void> _tapAndShowToast(WidgetTester tester, String label) async {
  final button = find.widgetWithText(CommonButton, label);
  await _scrollUntilVisible(tester, button);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _flushToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

// Split across cookbook_screen_test.dart / cookbook_screen_more_test.dart:
// running all ~24 tile-interaction tests in one file was observed to
// reliably leave one late test's ToastBanner AnimationController/Ticker
// undisposed at teardown (deterministic, position-dependent — reproduced
// and root-caused via bisection, not a guess) even though each test on its
// own, or the same tests run standalone, pass every time. `flutter test`
// runs each test FILE in its own isolate, so splitting the file is real
// isolation, not just a smaller number.
void main() {
  tearDown(() => Get.reset());

  testWidgets('renders every category section without crashing', (
    tester,
  ) async {
    await _boot();

    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    for (final section in const [
      'Storage & save data',
      'Economy & progression',
      'Live-ops & remote content',
      'Privacy, analytics & diagnostics',
      'Platform seams',
      'App/session infrastructure',
      'i18n, audio, haptics, theme',
    ]) {
      await _scrollUntilVisible(tester, find.text(section));
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DailyQuestService tile registers/increments/claims a real quest',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'DailyQuestService — register + progress + claim',
      );

      expect(find.textContaining('progress='), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets('VersionedJsonStore tile round-trips a real save', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'VersionedJsonStore — save + load');

    expect(find.textContaining('round-tripped:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('RemoteKillSwitchController tile resolves a real decision', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'RemoteKillSwitchController — isKilled');

    expect(find.textContaining('killed='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('SeasonEventService tile resolves a real window', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'SeasonEventService — currentWindow');

    expect(find.textContaining('active='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('GameTimeController tile ticks a real clock', (tester) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'GameTimeController — tick');

    expect(find.textContaining('step(s)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('MemoryWatchdog tile tracks and releases a real handle', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(
      tester,
      'MemoryWatchdog — track + orphans + release',
    );

    expect(find.textContaining('tracked id='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('HapticChoreographer tile plays a real pattern', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(
      tester,
      'HapticChoreographer — play a prebuilt pattern',
    );

    expect(find.textContaining('played HapticPattern.combo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('PurchaseSeam tile buys via the registered fake adapter', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'PurchaseSeam — buy via your adapter');

    expect(find.textContaining('bought=true'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets(
    'PluginAdapterConformanceSuite tile verifies the fake PurchaseSeam passes',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'PluginAdapterConformanceSuite — verify PurchaseSeam',
      );

      expect(find.textContaining('passed=true'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );
}
