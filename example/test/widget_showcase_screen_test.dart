import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit_example/screens/widget_showcase_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test for the common-widget-kit demo screen. `NeonBg` (used by the
/// screen) runs a permanent `Ticker`, so `pumpAndSettle()` never returns here
/// — use a bounded `pump(duration)` instead (see CLAUDE.md's testing note).
///
/// The screen's `ListView` is long (21 widget demos), so the default test
/// viewport only builds the first few lazily — grow the test surface so
/// every section is actually built and tappable without needing to scroll.
Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

Future<void> _pumpShowcase(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_wrap(const WidgetShowcaseScreen()));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  tearDown(Get.reset);

  testWidgets('renders every section without throwing', (tester) async {
    await _pumpShowcase(tester);

    expect(find.text('Buttons & Interactive'), findsOneWidget);
    expect(find.text('Feedback & Overlay'), findsOneWidget);
    expect(find.text('Progress & Reward'), findsOneWidget);
    expect(find.text('Layout & Cards'), findsOneWidget);
    expect(find.text('Level Select'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.byType(RibbonBadge), findsWidgets);
    expect(find.byType(ShopItemCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShopItemCard demo buy button shows a toast', (tester) async {
    await _pumpShowcase(tester);

    await tester.tap(find.text(r'$0.99').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Purchased!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Let the toast's auto-dismiss timer (2s) + reverse animation finish so
    // no pending Future/AnimationController survives past this test.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('interactive demos update local state on tap', (tester) async {
    await _pumpShowcase(tester);

    // Toggle the candy switch.
    await tester.tap(find.byType(CandyToggleSwitch));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('On'), findsOneWidget);

    // Bump the currency counter. CommonButton renders its label as a
    // stacked stroke+fill StrokeText, so 2 Text widgets match — the fill
    // Text paints on top and is the one that actually hit-tests, so tap
    // .last (mirrors settings_screen_test.dart's note about this pattern).
    await tester.tap(find.text('+25').last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('125'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'CoinFlyOverlay demo: Fly +25 flies 5 coins to CurrencyCounter, bumping '
    'it by 5 per arrival, then self-removes',
    (tester) async {
      await _pumpShowcase(tester);

      // CommonButton renders its label as a stacked stroke+fill StrokeText
      // (2 Text matches) — tap .last, same convention as the '+25' test
      // above.
      await tester.tap(find.text('Fly +25').last);
      await tester.pump(); // insert CoinFlyOverlay entry

      expect(find.byType(CoinFlyOverlay), findsOneWidget);

      // Default duration 550ms + stagger 70ms * 4 = 830ms total timeline for
      // 5 coins, then CurrencyCounter's own 500ms count-up tween on top of
      // that once the last arrival bumps its value — bounded pumps well
      // past both (NOT pumpAndSettle, NeonBg's permanent ticker never
      // settles, see CLAUDE.md).
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.text('125'), findsOneWidget);
      expect(find.byType(CoinFlyOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Page Dots demo: swiping the PageView moves the highlight', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    expect(find.text('Page Dots'), findsOneWidget);
    expect(find.byType(PaginatedDotsIndicator), findsOneWidget);
    expect(
      tester
          .widget<PaginatedDotsIndicator>(find.byType(PaginatedDotsIndicator))
          .currentIndex,
      0,
    );

    await tester.drag(find.text('Page 1'), const Offset(-800, 0));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Page 2'), findsOneWidget);
    expect(
      tester
          .widget<PaginatedDotsIndicator>(find.byType(PaginatedDotsIndicator))
          .currentIndex,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('CountdownChip demo: live countdown, restart resets it', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    expect(find.text('CountdownChip'), findsOneWidget);
    expect(find.text(fmtDur(const Duration(seconds: 15))), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(fmtDur(const Duration(seconds: 14))), findsOneWidget);

    await tester.tap(find.text('Restart 15s').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(fmtDur(const Duration(seconds: 15))), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SoundToggleFab demo: renders and toggles when AudioManager exists',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      Get.put(StorageService(await SharedPreferences.getInstance()));
      final audio = Get.put(AudioManager(), permanent: true);

      await _pumpShowcase(tester);

      expect(find.text('SoundToggleFab'), findsOneWidget);
      expect(find.byType(SoundToggleFab), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byType(SoundToggleFab));
      await tester.pump(const Duration(milliseconds: 100));

      expect(audio.muted.value, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RewardPopup dialog opens and dismisses without throwing', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    await tester.tap(find.text('Show reward').last);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Level Complete!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // ENH-08: the reward popup must render via NeonDialog's overlay pattern,
    // not Flutter's native `showDialog`/`Dialog` route widget.
    expect(find.byType(Dialog), findsNothing);

    // Dismiss by tapping the barrier.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('ConfettiOverlay: triggering it repeatedly does not crash', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    // CommonButton renders its label as a stacked stroke+fill StrokeText, so
    // 2 Text widgets match — the fill Text paints on top and is the one that
    // actually hit-tests (mirrors the pattern already used elsewhere in this
    // file / settings_screen_test.dart).
    final trigger = find.text('Trigger').last;

    // Re-trigger mid-burst a few times — the bug this widget's spec (FEAT-18)
    // explicitly calls out is a leaked Ticker/AnimationController on retrigger.
    for (var i = 0; i < 3; i++) {
      await tester.tap(trigger);
      await tester.pump(const Duration(milliseconds: 150));
    }
    // Let the last burst finish and hide itself.
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
  });

  testWidgets('LevelSelectGrid: tapping the unlocked node fires onLevelTap', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    // Sample data: level 4 is the only `unlocked` node (1-3 completed,
    // 5-8 locked).
    await tester.tap(find.text('4'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Level 4 tapped'), findsOneWidget);

    // ToastBanner.show uses its 2s default duration + a 220ms/180ms
    // in/out transition — let it fully self-remove and dispose its
    // AnimationController before the test ends, or its still-pending
    // Future.delayed(remove) timer fails the test on teardown.
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Network Banner demo toggles offline/online', (tester) async {
    await _pumpShowcase(tester);

    expect(find.byType(NetworkStatusBanner), findsOneWidget);
    expect(find.text('No internet connection'), findsNothing);

    await tester.tap(find.text('Go offline').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No internet connection'), findsOneWidget);

    await tester.tap(find.text('Go online').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No internet connection'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Shimmer Loading demo toggles between shimmer and content', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    expect(find.byType(ShimmerPlaceholder), findsWidgets);
    expect(find.text('Shop item loaded'), findsNothing);

    await tester.tap(find.text('Show loaded content').last);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShimmerPlaceholder), findsNothing);
    expect(find.text('Shop item loaded'), findsOneWidget);

    await tester.tap(find.text('Show shimmer').last);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ShimmerPlaceholder), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SpotlightOverlay demo: Start tutorial highlights the Primary button, '
    'Got it dismisses it',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.byType(SpotlightOverlay), findsNothing);

      // CommonButton renders its label as a stacked stroke+fill StrokeText,
      // so 2 Text widgets match — the fill Text paints on top and is the
      // one that actually hit-tests (same pattern as elsewhere in this
      // file / settings_screen_test.dart).
      await tester.tap(find.text('Start tutorial').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SpotlightOverlay), findsOneWidget);
      expect(find.text('Try this'), findsOneWidget);

      await tester.tap(find.text('Got it').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SpotlightOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FloatingComboText spam button triggers without throwing or '
      'leaking', (tester) async {
    await _pumpShowcase(tester);

    await tester.tap(find.text('Spam combo x5').last);
    // 5 triggers staggered 90ms apart + 900ms rise/fade each. Pump in small
    // steps (not one big jump) — a controller created by a Future.delayed
    // callback mid-pump only starts ticking on the *next* pump call, so a
    // single large pump() wouldn't let a late-started one finish.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FloatingComboText), findsWidgets);
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(FloatingComboText), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
