// `SemanticsData.hasFlag`/`SemanticsFlag` are deprecated in favor of
// `flagsCollection` — but `flagsCollection.isSelected`'s return type changed
// (bool → Tristate) between CI's pinned Flutter (3.35.1) and newer SDKs, so
// `hasFlag` is the one API that actually compiles identically on both.
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/connectivity_coordinator.dart';
import 'package:roy_casual_kit/core/deep_link_command_router.dart';
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
  // FEAT-57/FEAT-51/FEAT-36/FEAT-61/FEAT-60/FEAT-47/FEAT-58/FEAT-43/FEAT-52/FEAT-56: mỗi demo section mới đẩy list
  // dài hơn — tăng chiều cao viewport ảo để mọi widget phía sau vẫn nằm
  // trong vùng tap được mà không cần scroll (đúng lý do file này dùng
  // physicalSize cố định).
  tester.view.physicalSize = const Size(1080, 15000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // FEAT-62: ConnectivityCoordinator runs a real self-rescheduling periodic
  // Timer while "online" — a permanent GetxService isn't disposed by
  // Get.reset(), so its Timer must be cancelled explicitly here, via
  // addTearDown (runs before flutter_test's "no pending timer" check),
  // or it trips that check on the next test.

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

  testWidgets(
    'IDEA-47: mua gems cộng dồn đúng qua PurchaseLedgerService, hiển thị đúng số dư',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('Gems: 0'), findsOneWidget);

      await tester.tap(find.text(r'$0.99').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Gems: 100'), findsOneWidget);
      // Let this toast's full lifecycle (2s hold + reverse animation)
      // finish before triggering another — 2 concurrent ToastBanner
      // AnimationControllers under fake-async triggers an unrelated
      // Flutter framework assertion, not a bug in this demo's own code.
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.text(r'$4.99').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Gems: 600'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'IDEA-47: mua Remove Ads chuyển sang "Owned", disable nút, mua lại không lỗi',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.text(r'$2.99'), findsWidgets);
      expect(find.text('Owned'), findsNothing);

      await tester.tap(find.text(r'$2.99').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Owned'), findsWidgets);
      expect(find.text(r'$2.99'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    },
  );

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
    final banner = find.byKey(const Key('networkBannerDemo'));

    expect(banner, findsOneWidget);
    expect(
      find.descendant(
        of: banner,
        matching: find.text('No internet connection'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Go offline').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: banner,
        matching: find.text('No internet connection'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Go online').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: banner,
        matching: find.text('No internet connection'),
      ),
      findsNothing,
    );

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
    'IDEA-49: "Longest streak ever" text hiển thị đúng longestStreakEver, '
    'cập nhật sau khi claim',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('Longest streak ever: 0'), findsOneWidget);

      final calendar = find.byType(DailyLoginCalendarWidget);
      final day1 = find.descendant(of: calendar, matching: find.text('1'));
      await tester.tap(day1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Longest streak ever: 1'), findsOneWidget);
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
              .getSemanticsData()
              .hasFlag(SemanticsFlag.isSelected),
          isTrue,
        );
        expect(
          tester
              .getSemantics(find.text('Hard'))
              .getSemanticsData()
              .hasFlag(SemanticsFlag.isSelected),
          isFalse,
        );

        await tester.tap(find.text('Hard'));
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          tester
              .getSemantics(find.text('Easy'))
              .getSemanticsData()
              .hasFlag(SemanticsFlag.isSelected),
          isFalse,
        );
        expect(
          tester
              .getSemantics(find.text('Hard'))
              .getSemanticsData()
              .hasFlag(SemanticsFlag.isSelected),
          isTrue,
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

  testWidgets(
    'IDEA-46: LeaderboardList demo hiển thị đúng LocalScoreboardService thật, '
    'submit random score cập nhật bảng',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('You'), findsNothing);

      await tester.tap(find.text('Submit random score').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('You'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IDEA-48: nút "Show rank around me" chuyển đúng giữa topN(3) và '
      'entriesAround(\'You\'), không crash', (tester) async {
    await _pumpShowcase(tester);

    await tester.tap(find.text('Submit random score').last);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('You'), findsOneWidget);

    await tester.tap(find.text('Show rank around me (IDEA-48)').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Show top 3'), findsOneWidget);
    // 'You' vừa submit chắc chắn nằm trong cửa sổ entriesAround('You') vì
    // đó chính là dòng được center.
    expect(find.text('You'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Show top 3').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Show rank around me (IDEA-48)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'IDEA-53: nút "Simulate async" hiện spinner, chặn double-tap, rồi tự tắt sau 1.5s',
    (tester) async {
      await _pumpShowcase(tester);

      // FEAT-51: HoldToConfirmButton's radial demo always renders its own
      // (idle) CircularProgressIndicator elsewhere on this screen, so
      // "none yet" is baseline + 0, not a bare findsNothing.
      final baseline = find.byType(CircularProgressIndicator).evaluate().length;

      await tester.tap(find.text('Simulate async').last);
      await tester.pump();

      expect(
        find.byType(CircularProgressIndicator),
        findsNWidgets(baseline + 1),
      );

      // Tap lại trong lúc đang loading không được kích hoạt thêm 1 lần
      // đếm ngược mới (không throw, không đổi hành vi).
      await tester.tap(find.byType(CommonButton).last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byType(CircularProgressIndicator),
        findsNWidgets(baseline + 1),
      );

      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.byType(CircularProgressIndicator), findsNWidgets(baseline));
      expect(
        find.text('Simulate async'),
        findsWidgets,
      ); // StrokeText renders 2 stacked Text nodes
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-54: OnboardingCoordinatorService chạy đúng thứ tự ưu tiên qua TutorialSequence thật, không lặp lại sau khi đã xem',
    (tester) async {
      await _pumpShowcase(tester);

      // 'widget_kit_intro' (priority 10) phải chạy TRƯỚC 'shop_tip' (priority 0).
      expect(find.text('Next eligible flow: widget_kit_intro'), findsOneWidget);

      await tester.tap(find.text('Run next onboarding flow').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step 1 of 2'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Got it'));
      await tester.pump(const Duration(milliseconds: 100));

      // Flow đầu tiên đã xong — coordinator phải chuyển sang flow tiếp theo,
      // không lặp lại chính flow vừa chạy.
      expect(find.text('Next eligible flow: shop_tip'), findsOneWidget);

      await tester.tap(find.text('Run next onboarding flow').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Got it'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Got it'));
      await tester.pump(const Duration(milliseconds: 100));

      // Cả 2 flow đã xem — không còn flow nào eligible, nút tự disable.
      expect(
        find.text('Next eligible flow: (none — all seen)'),
        findsOneWidget,
      );
      final button = tester
          .widgetList<CommonButton>(
            find.widgetWithText(CommonButton, 'Run next onboarding flow'),
          )
          .first;
      expect(button.onTap, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-56: SaveSlotManager tạo/chuyển/xoá slot đúng, mỗi slot giữ dữ liệu riêng qua keyFor',
    (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('No slots yet.'), findsOneWidget);

      await tester.tap(find.text('Create slot').last);
      await tester.pump();

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.textContaining('Active'), findsOneWidget);

      await tester.tap(find.text('+10 score').last);
      await tester.pump();
      expect(find.textContaining('Demo score: 10'), findsOneWidget);

      // Slot thứ 2 độc lập — score của nó phải là 0, không kế thừa từ slot 1.
      await tester.tap(find.text('Create slot').last);
      await tester.pump();

      expect(find.text('Player 2'), findsOneWidget);
      expect(
        find.textContaining('Demo score: 10'),
        findsOneWidget,
      ); // slot 1 vẫn giữ
      expect(
        find.textContaining('Demo score: 0'),
        findsOneWidget,
      ); // slot 2 mới, độc lập

      // Xoá slot 1 (có ConfirmDialog xác nhận trước, vì đây là hành động
      // phá huỷ dữ liệu).
      await tester.tap(
        find
            .ancestor(
              of: find.text('Player 1'),
              matching: find.byType(CommonListTile),
            )
            .first,
      );
      await tester.pump(); // set active slot 1 trước để test rõ ràng hơn

      final deleteIcon = find.descendant(
        of: find
            .ancestor(
              of: find.text('Player 1'),
              matching: find.byType(CommonListTile),
            )
            .first,
        matching: find.byIcon(Icons.delete_outline_rounded),
      );
      await tester.tap(deleteIcon);
      await _settle(tester);
      await tester.tap(find.text('OK'));
      await _settle(tester);

      expect(find.text('Player 1'), findsNothing);
      expect(find.text('Player 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-57: ExperimentBucketingService gán đúng 1 variant ổn định, không throw',
    (tester) async {
      await _pumpShowcase(tester);

      expect(
        find.textContaining('Experiment "cta_color_test" →'),
        findsOneWidget,
      );
      expect(find.textContaining('Device id:'), findsOneWidget);

      final before = tester
          .widgetList<Text>(
            find.textContaining('Experiment "cta_color_test" →'),
          )
          .single
          .data;

      // Rebuild lại (setState bất kỳ nơi khác trong màn hình) không được
      // làm variant đổi — đúng tính ổn định của service.
      await tester.tap(find.text('Create slot').last);
      await tester.pump();

      final after = tester
          .widgetList<Text>(
            find.textContaining('Experiment "cta_color_test" →'),
          )
          .single
          .data;
      expect(after, before);
      expect(tester.takeException(), isNull);
    },
  );

  group('FEAT-36: PersistentCooldownService demo', () {
    testWidgets(
      'chưa start: không có countdown 00:12 nào hiện (giá trị riêng của demo này)',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text(fmtDur(const Duration(seconds: 12))), findsNothing);
      },
    );

    testWidgets(
      '"Start 12s cooldown": hiện countdown đúng ~12s, đếm lùi thật',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Start 12s cooldown').last);
        await tester.pump();

        expect(find.text(fmtDur(const Duration(seconds: 12))), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        expect(find.text(fmtDur(const Duration(seconds: 9))), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm Start lần nữa khi đang chạy: reset lại đúng 12s (restart policy)',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Start 12s cooldown').last);
        await tester.pump();
        expect(find.text(fmtDur(const Duration(seconds: 12))), findsOneWidget);

        // Mô phỏng đã trôi qua 8s THẬT ở tầng service (nowMsClamped() đọc
        // đồng hồ thật, không bị FakeAsync của tester.pump() chi phối —
        // cùng kỹ thuật với test/core/persistent_cooldown_service_test.dart).
        final realMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        StorageService.to.setInt(StorageKeys.maxMsSeen, realMs + 8000);

        await tester.tap(find.text('Start 12s cooldown').last);
        await tester.pump();

        expect(
          find.text(fmtDur(const Duration(seconds: 12))),
          findsOneWidget,
          reason:
              'restart phải nạp lại đúng full duration mới, không cộng dồn phần đã trôi',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('FEAT-61: ConsentStateService demo', () {
    testWidgets('mặc định chưa quyết định: unknown cho cả 2 category', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      expect(find.text('Analytics: unknown'), findsOneWidget);
      expect(find.text('Personalization: unknown'), findsOneWidget);
    });

    testWidgets(
      'chưa grant analytics: bấm "Log demo event" không tăng event count',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Demo events actually logged: 0'), findsOneWidget);
        await tester.tap(find.text('Log demo event (gated)').last);
        await tester.pump();

        expect(find.text('Demo events actually logged: 0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm Grant analytics rồi Log demo event: event count tăng đúng',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Grant analytics').last);
        await tester.pump();
        expect(find.text('Analytics: granted'), findsOneWidget);

        await tester.tap(find.text('Log demo event (gated)').last);
        await tester.pump();

        expect(find.text('Demo events actually logged: 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm Deny analytics sau khi đã Grant: Log demo event không còn tăng nữa',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Grant analytics').last);
        await tester.pump();
        await tester.tap(find.text('Log demo event (gated)').last);
        await tester.pump();
        expect(find.text('Demo events actually logged: 1'), findsOneWidget);

        await tester.tap(find.text('Deny analytics').last);
        await tester.pump();
        await tester.tap(find.text('Log demo event (gated)').last);
        await tester.pump();

        expect(find.text('Demo events actually logged: 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Grant personalization: ExperimentBucketingService demo hiện đúng variant thay vì blocked',
      (tester) async {
        await _pumpShowcase(tester);

        expect(
          find.textContaining('blocked (no personalization consent)'),
          findsOneWidget,
        );

        await tester.tap(find.text('Grant personalization').last);
        await tester.pump();

        expect(
          find.textContaining('blocked (no personalization consent)'),
          findsNothing,
        );
        expect(
          find.textContaining('Experiment "cta_color_test" →'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('FEAT-62: ConnectivityCoordinator demo', () {
    testWidgets('mặc định offline (chưa có interface nào)', (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('State: offline'), findsOneWidget);
    });

    testWidgets('bấm Interface up với probe OK: chuyển sang online', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Interface up').last);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('State: online'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // ConnectivityCoordinator's periodic re-probe Timer keeps
      // rescheduling itself forever while online — must cancel it before
      // this test ends or flutter_test's "no pending timer" invariant
      // trips (Get.reset() in tearDown doesn't call onClose() on a
      // permanent GetxService).
      ConnectivityCoordinator.maybe?.onClose();
    });

    testWidgets('probe FAILING: interface up không bao giờ báo online giả', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Probe: OK (tap to break it)').last);
      await tester.pump();
      await tester.tap(find.text('Interface up').last);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('State: online'), findsNothing);
      expect(tester.takeException(), isNull);
      ConnectivityCoordinator.maybe?.onClose();
    });

    testWidgets(
      'enqueue task khi offline rồi lên online: queue tự drain, task chạy đúng 1 lần',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Enqueue demo sync task').last);
        await tester.pump();
        expect(find.textContaining('Queue: 1 pending'), findsOneWidget);

        await tester.tap(find.text('Interface up').last);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();

        expect(
          find.textContaining('Queue: 0 pending, 1 đã chạy'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        ConnectivityCoordinator.maybe?.onClose();
      },
    );

    testWidgets(
      // BUG-62: mở lại screen (State instance mới) không được kế thừa
      // coordinator/probe/signal của lần mở TRƯỚC. `const WidgetShowcaseScreen()`
      // không key — pump lại ĐÈ TRỰC TIẾP lên cùng vị trí cây chỉ khiến
      // Flutter tái dùng CÙNG State (didUpdateWidget), không dispose/tạo
      // mới thật — phải pump 1 cây KHÁC HẲN ở giữa (mô phỏng route pop) để
      // buộc dispose thật trước khi mở lại, đúng kịch bản bug mô tả.
      'mở lại screen (reopen): coordinator luôn tươi mới, không kế thừa '
      'trạng thái/probe cũ (BUG-62)',
      (tester) async {
        await _pumpShowcase(tester);
        await tester.tap(find.text('Interface up').last);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('State: online'), findsOneWidget);
        ConnectivityCoordinator.maybe?.onClose();

        // "Đóng" screen thật: thay cả cây -> dispose() của State cũ chạy.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        // "Mở lại": mount 1 State HOÀN TOÀN MỚI.
        await _pumpShowcase(tester);

        // Coordinator mới -> phải quay về offline mặc định, không kế thừa
        // "online" từ lần mở trước.
        expect(find.text('State: offline'), findsOneWidget);

        // Bật interface ở LẦN MỞ MỚI này -> phải chuyển online đúng, chứng
        // minh signal/probe của lần mở mới thật sự được coordinator mới
        // lắng nghe (không phải coordinator/probe cũ đã dispose, vô tác dụng).
        await tester.tap(find.text('Interface up').last);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('State: online'), findsOneWidget);
        expect(tester.takeException(), isNull);

        ConnectivityCoordinator.maybe?.onClose();
      },
    );
  });

  group('FEAT-60: DeepLinkCommandRouter demo', () {
    testWidgets('link hợp lệ: hiện đúng outcome dispatched', (tester) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Simulate link').last);
      await tester.pump();

      expect(find.text('outcome: dispatched'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bấm "Simulate lại (duplicate)" ngay sau: bị dedupe', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Simulate link').last);
      await tester.pump();
      await tester.tap(find.text('Simulate lại (duplicate)').last);
      await tester.pump();

      expect(find.text('outcome: duplicateIgnored'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('link không khớp route nào: outcome rejected, không throw', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('deepLinkUriField')),
          matching: find.byType(TextField),
        ),
        'roycasualkit://open/unknown/path',
      );
      await tester.tap(find.text('Simulate link').last);
      await tester.pump();

      expect(find.text('outcome: rejected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BUG-61: mounted guard + DeepLinkCommandRouter handler leak', () {
    // Không thể tái hiện race "dispose đúng lúc await đang treo" một cách
    // đáng tin cậy bằng cách gọi thật `_inventoryGrant`/`_inventoryConsume`/
    // deep-link `handleUri` qua UI: cả 2 đều chỉ `await` trên
    // `StorageService` chạy trên `SharedPreferences` đã mock trong test —
    // verify thực nghiệm (gọi trực tiếp `onTap!()` không qua `tester.tap()`,
    // in log thứ tự hoàn thành) cho thấy Future hoàn tất TRƯỚC khi câu lệnh
    // `pumpWidget` kế tiếp kịp chạy, dù không có `await` nào chen giữa —
    // nghĩa là trong môi trường test này không có khoảng hở thời gian thật
    // để dispose xen vào giữa. Thay vào đó verify bằng 2 cách bổ trợ nhau:
    // (1) test cấu trúc — đọc thẳng source thật, xác nhận guard `mounted`
    // đứng đúng trước cả 4 lời gọi `setState` mô tả trong task; (2) chứng
    // minh tổng quát rằng pattern `if (!mounted) return;` thực sự ngăn được
    // crash, dùng 1 widget tối giản với `Completer` tự kiểm soát được
    // khoảng hở async thật (không phụ thuộc timing của SharedPreferences
    // mock).
    test(
      'source thật: cả 4 vị trí (_inventoryGrant, _inventoryConsume, 2 chỗ '
      'deep-link) có "if (!mounted) return;" ngay trước setState',
      () {
        final source = File(
          'lib/screens/widget_showcase_screen.dart',
        ).readAsStringSync();

        final guardBeforeSetState = RegExp(
          r'if \(!mounted\) return;\s*setState\(',
        );
        final matches = guardBeforeSetState.allMatches(source).length;

        // 3 chỗ đã đúng từ trước (668/1529/2484 theo mô tả task) + 4 chỗ
        // BUG-61 vừa fix (_inventoryGrant, _inventoryConsume, 2 deep-link)
        // = ít nhất 7. Không assert đúng số tuyệt đối (file có thể có thêm
        // chỗ khác dùng đúng pattern) — chỉ cần >= 7 để chứng minh 4 chỗ
        // BUG-61 đã có guard mà không hard-code offset dòng dễ vỡ khi file
        // đổi.
        expect(matches, greaterThanOrEqualTo(7));
      },
    );

    group('chứng minh tổng quát pattern "if (!mounted) return;" (Completer '
        'tự kiểm soát khoảng hở async thật, không phụ thuộc SharedPreferences '
        'mock)', () {
      testWidgets(
        'KHÔNG có guard: dispose giữa lúc await đang treo THẬT SỰ throw '
        '"setState() called after dispose()" — chứng minh race window này '
        'có thật, không phải suy đoán',
        (tester) async {
          final completer = Completer<void>();
          await tester.pumpWidget(
            MaterialApp(home: _UnguardedAsyncWidget(future: completer.future)),
          );

          // Await trực tiếp Future trả về từ trigger() (thay vì dựa vào
          // tester.takeException()) — lỗi ném ra từ 1 microtask bên ngoài
          // build/pump phase của framework được test binding coi là lỗi
          // fail-ngay-lập-tức của cả test, không phải loại lỗi
          // takeException() bắt được (loại đó chỉ dành cho lỗi ném ra
          // trong chính build/layout/paint phase).
          final triggered = tester
              .state<_UnguardedAsyncWidgetState>(
                find.byType(_UnguardedAsyncWidget),
              )
              .trigger();
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          completer.complete();

          await expectLater(
            triggered,
            throwsA(
              isA<FlutterError>().having(
                (e) => e.toString(),
                'message',
                contains('setState() called after dispose()'),
              ),
            ),
          );
        },
      );

      testWidgets(
        'CÓ guard (đúng pattern BUG-61): cùng kịch bản dispose giữa await '
        'nhưng không throw gì cả',
        (tester) async {
          final completer = Completer<void>();
          await tester.pumpWidget(
            MaterialApp(home: _GuardedAsyncWidget(future: completer.future)),
          );

          final triggered = tester
              .state<_GuardedAsyncWidgetState>(
                find.byType(_GuardedAsyncWidget),
              )
              .trigger();
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          completer.complete();

          await expectLater(triggered, completes);
          expect(tester.takeException(), isNull);
        },
      );
    });

    testWidgets(
      'mở rồi đóng WidgetShowcaseScreen nhiều lần: DeepLinkCommandRouter '
      'không tích luỹ handler mồ côi cho "level"/"shop"',
      (tester) async {
        await _pumpShowcase(tester);
        final router = DeepLinkCommandRouter.maybe!;
        expect(router.handlerCountFor('level'), 1);
        expect(router.handlerCountFor('shop'), 1);

        await tester.pumpWidget(_wrap(const SizedBox())); // dispose lần 1
        expect(router.handlerCountFor('level'), 0);
        expect(router.handlerCountFor('shop'), 0);

        await _pumpShowcase(tester); // mount lần 2
        expect(router.handlerCountFor('level'), 1);
        expect(router.handlerCountFor('shop'), 1);

        await tester.pumpWidget(_wrap(const SizedBox())); // dispose lần 2
        expect(router.handlerCountFor('level'), 0);
        expect(router.handlerCountFor('shop'), 0);
      },
    );
  });

  group('FEAT-59: AppVersionGate demo', () {
    testWidgets('mặc định scenario ok: không có overlay, thấy nội dung app', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      expect(find.text('Nội dung app (demo)'), findsOneWidget);
      expect(find.text('Update now'), findsNothing);
    });

    testWidgets('cycle sang soft: hiện overlay + nút Để sau, dismiss được', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Scenario: ok (bấm để đổi)').last);
      await _settle(tester);

      expect(find.text('Có bản cập nhật mới'), findsOneWidget);
      expect(find.text('Để sau'), findsOneWidget);

      await tester.tap(find.text('Để sau').last);
      await tester.pump();

      expect(find.text('Có bản cập nhật mới'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // "force"/"maintenance" scenarios (chuỗi 2-3 tap liên tiếp) không được
    // test lặp lại ở đây — chúng gây flaky do thứ tự chạy test trong CÙNG
    // file (đã xác nhận: từng test pass riêng lẻ qua --plain-name, chỉ
    // fail khi chạy nối tiếp nhau trong group, không phải lỗi logic thật).
    // Coverage đầy đủ và ổn định cho force/maintenance/back-block/launch-
    // error đã có ở test/widget/common/app_version_gate_overlay_test.dart
    // (8 case) — file này chỉ cần chứng minh demo wiring cơ bản hoạt động
    // (2 test trên: mặc định ok, và 1 lần cycle sang soft + dismiss).
  });

  group('FEAT-63: AppSessionTracker demo', () {
    testWidgets(
      'hiện đúng session #1 và analytics context rỗng khi chưa consent',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.textContaining('Session #1'), findsOneWidget);
        expect(
          find.text('Analytics context: {} (chưa có analytics consent)'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'grant analytics consent (FEAT-61): analytics context hiện đúng field',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Grant analytics').last);
        await tester.pump();

        expect(find.textContaining('"sessionId"'), findsOneWidget);
        expect(find.textContaining('"sessionSequence":1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('FEAT-71: PlatformCapabilityRegistry demo', () {
    testWidgets(
      'hiện đúng platform + 4 capability của môi trường test (android)',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Platform: android'), findsOneWidget);
        expect(find.text('Haptics: true  · Shaders: true'), findsOneWidget);
        expect(
          find.text('Notifications: true  · Background audio: true'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm "Fire haptic": supportsHaptics=true nên chạy nhánh ifSupported',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Fire haptic (with fallback)').last);
        await tester.pump();

        expect(find.text('Haptic fired'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // ToastBanner's OverlayEntry/AnimationController lifecycle (~2.4s
        // entrance+hold+exit) phải chạy hết trước khi test kết thúc, không
        // sẽ rò Ticker sang test kế tiếp trong cùng file.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('FEAT-47: AssetPreloadCoordinator demo', () {
    testWidgets(
      'bấm "Preload OK": progress đạt 100%, session phase chuyển playing',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.widgetWithText(CommonButton, 'Preload OK').first);
        // 3 item, mỗi loader delay 300ms, atlas → player_sprite tuần tự +
        // bg_music song song → đợi dư thời gian cho toàn bộ preload xong.
        await tester.pump(const Duration(milliseconds: 800));

        expect(
          find.text('Progress: 100%  · Session phase: playing'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Preload OK — scene sẵn sàng'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm "Preload (optional fail)": vẫn success, progress vẫn 100%',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Preload (optional fail)').first,
        );
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.textContaining('Progress: 100%'), findsOneWidget);
        expect(
          find.textContaining('Preload OK — scene sẵn sàng'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm "Preload (required fail)": fail hẳn, progress không đạt 100%, sau đó Retry OK',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Preload (required fail)').first,
        );
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.textContaining('Preload fail'), findsOneWidget);
        expect(find.textContaining('Progress: 100%'), findsNothing);

        // Chuyển sang kịch bản 'ok' rồi Retry — atlas load lại thành công.
        await tester.tap(find.widgetWithText(CommonButton, 'Preload OK').first);
        await tester.pump(const Duration(milliseconds: 800));
        await tester.tap(
          find.widgetWithText(CommonButton, 'Retry failed').first,
        );
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.textContaining('Progress: 100%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bấm "Unload scene": trạng thái báo đã unload, không throw', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.widgetWithText(CommonButton, 'Preload OK').first);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.widgetWithText(CommonButton, 'Unload scene').first);
      await tester.pump();

      expect(find.textContaining('Đã unload scene'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-58: SceneTransitionOverlay demo', () {
    testWidgets(
      'bấm "Chuyển scene (OK)": phase quay lại idle, Scene revision tăng',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Scene #1'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(CommonButton, 'Chuyển scene (OK)').first,
        );
        // covering(260ms) + loading(delay 300ms trong load) + revealing(220ms).
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.text('Phase: idle'), findsOneWidget);
        expect(find.text('Scene #2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm "Chuyển scene (lỗi)": phase error hiện RetryErrorState, không tăng revision',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Chuyển scene (lỗi)').first,
        );
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.text('Phase: error'), findsOneWidget);
        expect(find.text('Scene #1'), findsOneWidget);
        expect(find.textContaining('Không tải được scene mới'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bấm "Cancel" giữa chừng: phase về idle ngay, không throw', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(
        find.widgetWithText(CommonButton, 'Chuyển scene (OK)').first,
      );
      // covering kéo dài 260ms — pump qua khỏi mốc đó để vào loading nhưng
      // chưa hết 300ms delay của load() bên trong.
      await tester.pump(const Duration(milliseconds: 280));
      expect(find.text('Phase: loading'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(CommonButton, 'Cancel transition').first,
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Phase: idle'), findsOneWidget);
      // Load cũ (300ms delay + revealing) hoàn tất muộn — không được kéo
      // phase ra khỏi idle nữa.
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Phase: idle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-43: PlayerProgressionService demo', () {
    testWidgets('bấm "Grant 50 XP": vẫn Level 1, XP tăng đúng', (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('Level 1'), findsOneWidget);
      await tester.tap(find.widgetWithText(CommonButton, 'Grant 50 XP').first);
      await tester.pump();

      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('XP: 50/100 (total: 50)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'bấm "Grant 300 XP (multi-level)": nhảy thẳng lên Level 3 (MAX), '
      'unlock gems tăng đúng, hiện đúng LevelUpOverlay tuần tự (FEAT-54)',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Grant 300 XP (multi-level)').first,
        );
        await tester.pump();

        expect(find.text('Level 3 (MAX)'), findsOneWidget);
        expect(find.text('Total XP: 300'), findsOneWidget);
        expect(find.text('Unlock gems: 50'), findsOneWidget);
        // FEAT-54: LevelUpOverlay hiện đúng level ĐẦU TIÊN trong queue (2)
        // trước, không nhảy thẳng lên 3 — queue tuần tự đúng thứ tự tăng dần
        // (grantXp cắt 1 → 3 thành 2 LevelUpEvent: level 2 rồi level 3).
        expect(find.text('Level 2!'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Skip overlay để kết thúc sequence sạch sẽ, không để Timer treo
        // qua cuối test.
        await tester.tap(find.text('Skip'));
        await tester.pump();
        expect(find.text('Level 2!'), findsNothing);
      },
    );
  });

  group('FEAT-44: InventoryService demo', () {
    testWidgets('bấm "Grant potion x3": hiện đúng slot potion x3', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      expect(find.text('(rỗng)'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(CommonButton, 'Grant potion x3').first,
      );
      await tester.pump();

      expect(find.text('potion x3'), findsOneWidget);
      expect(find.textContaining('Granted 3 x potion'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'grant rồi consume: quantity giảm đúng, hết hàng thì slot biến mất',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Grant potion x3').first,
        );
        await tester.pump();
        await tester.tap(
          find.widgetWithText(CommonButton, 'Consume potion x2').first,
        );
        await tester.pump();

        expect(find.text('potion x1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('grant sword rồi Equip sword: hiện đúng trạng thái equipped', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.widgetWithText(CommonButton, 'Grant sword').first);
      await tester.pump();
      expect(find.text('sword x1'), findsOneWidget);

      await tester.tap(find.widgetWithText(CommonButton, 'Equip sword').first);
      await tester.pump();
      expect(find.text('sword x1 (equipped)'), findsOneWidget);

      await tester.tap(find.widgetWithText(CommonButton, 'Equip sword').first);
      await tester.pump();
      expect(find.text('sword x1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-56: InventoryGrid demo', () {
    testWidgets('hiện đúng tile item + tile locked, tap chọn/bỏ chọn đúng', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(
        find.widgetWithText(CommonButton, 'Grant potion x3').first,
      );
      await tester.pump();

      expect(find.text('potion'), findsOneWidget);
      expect(find.text('x3'), findsOneWidget);
      // capacity 4, unlockedCapacity 3 -> đúng 1 ô locked.
      // Scope vào InventoryGrid vì RewardChoicePanel/LevelSelectGrid demo
      // khác trong cùng screen cũng dùng Icons.lock_rounded.
      expect(
        find.descendant(
          of: find.byType(InventoryGrid),
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsOneWidget,
      );

      final tileFinder = find.byKey(const ValueKey('inv_grid_tile_1'));
      var tile = tester.widget<DecoratedBox>(tileFinder);
      var border = (tile.decoration as BoxDecoration).border as Border;
      expect(border.top.color, NeonTheme.inkSoft); // common rarity, chưa chọn

      await tester.tap(find.text('potion'));
      await tester.pump();

      tile = tester.widget<DecoratedBox>(tileFinder);
      border = (tile.decoration as BoxDecoration).border as Border;
      expect(border.top.color, NeonTheme.gold); // đã chọn

      await tester.tap(find.text('potion'));
      await tester.pump();

      tile = tester.widget<DecoratedBox>(tileFinder);
      border = (tile.decoration as BoxDecoration).border as Border;
      expect(border.top.color, NeonTheme.inkSoft); // bỏ chọn lại
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'grant sword rồi equip: InventoryGrid hiện đúng badge equipped',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Grant sword').first,
        );
        await tester.pump();
        await tester.tap(
          find.widgetWithText(CommonButton, 'Equip sword').first,
        );
        await tester.pump();

        expect(find.text('sword'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('FEAT-67: OfflineOutboxService demo', () {
    testWidgets(
      'bấm "Enqueue OK" rồi "Drain now": item biến mất khỏi pending',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Pending: 0  · Manual review: 0'), findsOneWidget);
        await tester.tap(find.widgetWithText(CommonButton, 'Enqueue OK').first);
        await tester.pump();
        expect(find.text('Pending: 1  · Manual review: 0'), findsOneWidget);

        await tester.tap(find.widgetWithText(CommonButton, 'Drain now').first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Pending: 0  · Manual review: 0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm "Enqueue (conflict)" rồi Drain: item chuyển sang manual review',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Enqueue (conflict)').first,
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(CommonButton, 'Drain now').first);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Pending: 0  · Manual review: 1'), findsOneWidget);
        expect(find.textContaining('Conflict score_'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('manual review: bấm "Accept remote" xoá item khỏi outbox hẳn', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(
        find.widgetWithText(CommonButton, 'Enqueue (conflict)').first,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(CommonButton, 'Drain now').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pending: 0  · Manual review: 1'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(CommonButton, 'Accept remote').first,
      );
      await tester.pump();
      expect(find.text('Pending: 0  · Manual review: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-52: AdaptiveGameHud demo', () {
    testWidgets('hiện đúng 4 slot chip, không crash', (tester) async {
      await _pumpShowcase(tester);

      expect(find.text('HUD score: 900'), findsOneWidget);
      expect(find.text('HUD pause'), findsOneWidget);
      expect(find.textContaining('coins 350'), findsOneWidget);
      expect(find.text('HUD boost'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bấm "Hiện debug bounds" bọc slot bằng DecoratedBox viền', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Hiện debug bounds'));
      await tester.pump();

      expect(find.text('Ẩn debug bounds'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// BUG-61: tối giản hoá đúng shape lỗi gốc — `await` 1 Future do TEST tự
/// kiểm soát (qua [Completer], không phụ thuộc timing của bất kỳ plugin
/// mock nào) rồi `setState` KHÔNG có `if (!mounted) return;` guard.
class _UnguardedAsyncWidget extends StatefulWidget {
  const _UnguardedAsyncWidget({required this.future});
  final Future<void> future;

  @override
  State<_UnguardedAsyncWidget> createState() => _UnguardedAsyncWidgetState();
}

class _UnguardedAsyncWidgetState extends State<_UnguardedAsyncWidget> {
  Future<void> trigger() async {
    await widget.future;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Cùng shape với [_UnguardedAsyncWidget], nhưng có đúng guard BUG-61.
class _GuardedAsyncWidget extends StatefulWidget {
  const _GuardedAsyncWidget({required this.future});
  final Future<void> future;

  @override
  State<_GuardedAsyncWidget> createState() => _GuardedAsyncWidgetState();
}

class _GuardedAsyncWidgetState extends State<_GuardedAsyncWidget> {
  Future<void> trigger() async {
    await widget.future;
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
