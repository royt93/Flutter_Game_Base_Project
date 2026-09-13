import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
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
  tester.view.physicalSize = const Size(1080, 8500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_wrap(const WidgetShowcaseScreen()));
  await tester.pump(const Duration(milliseconds: 100));
}

/// A single big `pump(bigDuration)` right after a tap that opens a modal
/// route (dialog/bottom sheet) leaves its entrance transition unsettled —
/// its `AnimationController` only actually starts ticking on its own first
/// frame, so one big jump measures barely any elapsed transition time
/// relative to that (verified empirically against `showConfirmDialog`/
/// `showCommonBottomSheet`, see settings_screen_test.dart's identical
/// gotcha for `_pickLanguage`'s sheet). Several smaller pumps let it
/// converge to its settled, tappable position instead.
Future<void> _settle(
  WidgetTester tester, {
  int steps = 8,
  int stepMs = 80,
}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(Duration(milliseconds: stepMs));
  }
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
    expect(find.text('Game Feel'), findsOneWidget);
    expect(find.byType(RibbonBadge), findsWidgets);
    expect(find.byType(ShopItemCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('IDEA-08: Game Feel demos respond to taps without throwing', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    // SquashStretch demo card: tapping bumps the displayed tap count.
    expect(find.text('Taps: 0'), findsOneWidget);
    await tester.tap(find.text('Taps: 0'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Taps: 1'), findsOneWidget);

    // ScreenShake demo: tapping "Shake!" starts a decaying shake — verify
    // the actual rendered displacement (ScreenShake's own
    // Transform.translate), not just "no exception": non-zero right after
    // the shake starts, back to Offset.zero once it's fully decayed
    // (bounded pump, not pumpAndSettle, per CLAUDE.md's NeonBg ticker
    // gotcha).
    Offset shakeOffset() {
      final translation = tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(ScreenShake),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .getTranslation();
      return Offset(translation.x, translation.y);
    }

    await tester.tap(find.text('Shake!').last);
    await tester.pump(const Duration(milliseconds: 50));
    expect(shakeOffset(), isNot(Offset.zero));

    await tester.pump(const Duration(milliseconds: 500));
    expect(shakeOffset(), Offset.zero);
    expect(tester.takeException(), isNull);

    // ComboHeatBackground demo: tapping "Bump heat" cycles the displayed
    // heat percentage.
    expect(find.text('Heat: 0%'), findsOneWidget);
    await tester.tap(find.text('Bump heat').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Heat: 25%'), findsOneWidget);

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

    // ENH-54: confirm the popup ACTUALLY closed, not just "no exception" —
    // a regression that stops the barrier tap from dismissing it would
    // otherwise pass this test silently.
    expect(find.text('Level Complete!'), findsNothing);
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
    // 5-8 locked). Scoped to LevelSelectGrid — the DailyLoginCalendarWidget
    // demo elsewhere on this screen also renders a bare "4" (day 4, an
    // unclaimed slot).
    await tester.tap(
      find.descendant(
        of: find.byType(LevelSelectGrid),
        matching: find.text('4'),
      ),
    );
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

  testWidgets(
    'VictoryCardTemplate demo renders title/stats/avatar/QR and a Share '
    'button, wrapped in a RepaintBoundary for share_helper wiring',
    (tester) async {
      await _pumpShowcase(tester);

      expect(
        find.text('VictoryCardTemplate (share_helper wiring)'),
        findsOneWidget,
      );
      // StrokeText stacks stroke+fill Text for the title, so 2 matches.
      expect(find.text('Level 50 Complete!'), findsWidgets);
      expect(find.text('Score: 12,340'), findsOneWidget);
      expect(find.text('Time: 01:23'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byType(VictoryCardTemplate), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(VictoryCardTemplate),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      // CommonButton renders its label via StrokeText (stroke+fill), so 2
      // Text matches — same convention noted elsewhere in this file.
      expect(find.text('Share'), findsWidgets);
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

  testWidgets(
    'BUG: CurrencyCounter demo row không tràn viền ở width hẹp thật (đo '
    'thật trên Samsung S24 Ultra: density override đẩy vùng chứa PanelCard '
    'xuống còn max-width 296 — tái hiện chính xác constraint đó, cô lập '
    'khỏi phần còn lại của màn hình vì các section khác đã có sẵn vấn đề '
    'tràn viền riêng ở width hẹp, không thuộc phạm vi bug này)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          Material(
            child: Center(
              child: SizedBox(
                width: 296,
                child: Wrap(
                  spacing: NeonTheme.s16,
                  runSpacing: NeonTheme.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const CurrencyCounter(value: 12345678),
                    const CommonButton(label: '+25', width: 90, onTap: null),
                    CommonButton(
                      label: 'Fly +25',
                      width: 110,
                      color: NeonTheme.gold,
                      onTap: null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Fly +25'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DailyLoginCalendarWidget demo: claiming today updates the displayed '
    'streak',
    (tester) async {
      await _pumpShowcase(tester);

      final calendar = find.byType(DailyLoginCalendarWidget);
      expect(calendar, findsOneWidget);
      // Fresh service, never claimed -> highlight/tappable day is 1. Scoped
      // to the widget itself — LevelSelectGrid elsewhere on this screen also
      // renders a bare "1" (level 1, completed).
      final day1 = find.descendant(of: calendar, matching: find.text('1'));
      expect(day1, findsOneWidget);

      await tester.tap(day1);
      await tester.pump(const Duration(milliseconds: 100));

      // Day 1 now claimed -> shown as a checkmark, not a bare '1', and
      // today's already claimed so the Claim button goes disabled.
      expect(
        find.descendant(of: calendar, matching: find.text('1')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: calendar,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'EnergyBar demo: consuming energy updates the displayed pips and shows '
    'a countdown',
    (tester) async {
      await _pumpShowcase(tester);

      final energyBar = find.byType(EnergyBar);
      expect(energyBar, findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNWidgets(5));
      // Fresh service starts full -> no countdown text yet. Scoped to the
      // widget itself — the CountdownChip/VictoryCardTemplate demos
      // elsewhere on this screen also render "mm:ss"-shaped text.
      expect(
        find.descendant(of: energyBar, matching: find.textContaining(':')),
        findsNothing,
      );

      await tester.tap(find.text('Consume 1 energy').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.favorite), findsNWidgets(4));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(1));
      // A real ~30-minute countdown now shows — not asserting the exact
      // "30:00" text since a few ms of real wall-clock time elapse between
      // EnergyService recording its baseline and this rebuild reading it
      // back, which can legitimately round down to "29:59".
      expect(
        find.descendant(of: energyBar, matching: find.textContaining(':')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-55: previously-untested demo interactions', () {
    // The 3 newest widgets (per Đề xuất's priority) first.
    testWidgets(
      'TutorialSequence: "Start 2-step tutorial" chains both steps then ends',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Step 1 of 2'), findsNothing);

        await tester.tap(find.text('Start 2-step tutorial').last);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Step 1 of 2'), findsOneWidget);
        expect(find.textContaining('Primary button'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Step 1 of 2'), findsNothing);
        expect(find.text('Step 2 of 2'), findsOneWidget);
        expect(find.textContaining('coin balance'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Step 2 of 2'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('WheelSpinner: "Spin" ends with a "Landed on ..." toast', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      expect(find.textContaining('Landed on'), findsNothing);

      await tester.tap(find.text('Spin').last);
      // Default spinDuration is 3s — several smaller pumps (not one big
      // jump) let the AnimationController's whenComplete() actually fire.
      await _settle(tester, steps: 20, stepMs: 200);

      expect(find.textContaining('Landed on'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Drain the toast's own auto-dismiss timer + reverse animation
      // before the test ends.
      await _settle(tester, steps: 30, stepMs: 100);
    });

    testWidgets(
      'GameOverCardTemplate: primary/secondary actions each show the matching toast',
      (tester) async {
        await _pumpShowcase(tester);

        // StrokeText renders a stroke Text + a fill Text stacked.
        expect(find.text('Out of moves!'), findsWidgets);

        await tester.tap(find.text('Retry').last);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Retry tapped'), findsOneWidget);

        // Let the toast's own timer + reverse animation finish before the
        // next tap — incremental pumps, not 1 big jump, so the reverse
        // Ticker started mid-elapse actually gets driven to completion
        // instead of outliving the test (same class of gotcha as _settle).
        await _settle(tester, steps: 30, stepMs: 100);

        await tester.tap(find.text('Home').last);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Home tapped'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Drain this toast's own auto-dismiss timer too, same reason.
        await _settle(tester, steps: 30, stepMs: 100);
      },
    );

    testWidgets(
      'SegmentedTabBar: tapping a tab actually changes which one is selected',
      (tester) async {
        await _pumpShowcase(tester);

        expect(
          tester
              .getSemantics(find.text('Easy'))
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          true,
        );
        expect(
          tester
              .getSemantics(find.text('Hard'))
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          false,
        );

        await tester.tap(find.text('Hard'));
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          tester
              .getSemantics(find.text('Easy'))
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          false,
        );
        expect(
          tester
              .getSemantics(find.text('Hard'))
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          true,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'IconBadgeButton: tapping the mail icon bumps its displayed unread count',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('12'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.mail_rounded));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('12'), findsNothing);
        expect(find.text('13'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TooltipBubble: both demo instances actually render with their given text',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Tap to pop!'), findsOneWidget);
        expect(find.text('Combo x3'), findsOneWidget);
        expect(find.byType(TooltipBubble), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LoadingOverlay: "Show for 1.2s" shows it then auto-hides after the delay',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Loading...'), findsNothing);

        await tester.tap(find.text('Show for 1.2s').last);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Loading...'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1200));
        expect(find.text('Loading...'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ConfirmDialog: "Delete..." opens the dialog, confirming shows the matching toast',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Delete...').last);
        await _settle(tester);

        expect(find.text('Delete save?'), findsOneWidget);

        await tester.tap(find.text('OK'));
        await _settle(tester);

        expect(find.text('Delete save?'), findsNothing);
        expect(find.text('Confirmed'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Drain the toast's own auto-dismiss timer + reverse animation
        // before the test ends (incremental pumps, see _settle's comment).
        await _settle(tester, steps: 30, stepMs: 100);
      },
    );

    testWidgets(
      'BottomSheetPanel: "Open sheet" shows the quick-actions list, tapping an action closes it',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Quick actions'), findsNothing);

        await tester.tap(find.text('Open sheet').last);
        await _settle(tester);

        expect(find.text('Quick actions'), findsOneWidget);
        expect(find.text('Restart level'), findsOneWidget);

        await tester.tap(find.text('Restart level'));
        await _settle(tester);

        expect(find.text('Quick actions'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ProgressBarStars/CircularProgressRing: "+20% progress" bumps the shared progress value',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('40%'), findsOneWidget);

        await tester.tap(find.text('+20% progress').last);
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('40%'), findsNothing);
        expect(find.text('60%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'StarRating: "Cycle stars" advances the earned-star count (wraps back after 3)',
      (tester) async {
        await _pumpShowcase(tester);

        final starRow = find
            .ancestor(
              of: find.text('Cycle stars'),
              matching: find.byType(Column),
            )
            .first;
        expect(
          find.descendant(
            of: starRow,
            matching: find.byIcon(Icons.star_rounded),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Cycle stars').last);
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.descendant(
            of: starRow,
            matching: find.byIcon(Icons.star_rounded),
          ),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
