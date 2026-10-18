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
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/core/juicy_feedback.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/reminder_service.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/core/utils/smart_reminder_scheduling.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';
import 'package:roy_casual_kit/presentation/widgets/spring_scale_transition.dart';
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
  // FEAT-57/FEAT-51/FEAT-36/FEAT-61/FEAT-60/FEAT-47/FEAT-58/FEAT-43/FEAT-52/FEAT-56/ENH-90/FEAT-130/FEAT-139:
  // mỗi demo section mới đẩy list dài hơn — tăng chiều cao viewport ảo để
  // mọi widget phía sau vẫn nằm trong vùng tap được mà không cần scroll
  // (đúng lý do file này dùng physicalSize cố định).
  tester.view.physicalSize = const Size(1080, 32000);
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

/// Throws ONLY on `setString(targetKey, ...)` — every other write succeeds
/// normally. Used to simulate a real persist failure for exactly one
/// service's storage key without breaking every other service the demo
/// screen also constructs during `initState`.
class _ThrowingOnKeyStorage extends StorageService {
  _ThrowingOnKeyStorage(super.prefs, this.targetKey);
  final String targetKey;

  @override
  Future<void> setString(String key, String value) {
    if (key == targetKey) throw StateError('simulated persist failure');
    return super.setString(key, value);
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
    final gameFeel = find.text('Game Feel');
    await tester.scrollUntilVisible(
      gameFeel,
      350,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(gameFeel, findsOneWidget);
    expect(find.byType(RibbonBadge), findsWidgets);
    expect(find.byType(ShopItemCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('IDEA-08: Game Feel demos respond to taps without throwing', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    // SquashStretch demo card: tapping bumps the displayed tap count.
    final taps = find.text('Taps: 0');
    await tester.scrollUntilVisible(
      taps,
      350,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(taps, findsOneWidget);
    await tester.ensureVisible(taps);
    await tester.pump();
    await tester.tap(taps);
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

    final shakeButton = find.widgetWithText(CommonButton, 'Shake!');
    for (var i = 0; i < 20 && shakeButton.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(shakeButton.last);
    await tester.pump();
    await tester.tap(shakeButton.last);
    await tester.pump(const Duration(milliseconds: 50));
    expect(shakeOffset(), isNot(Offset.zero));

    await tester.pump(const Duration(milliseconds: 500));
    expect(shakeOffset(), Offset.zero);
    expect(tester.takeException(), isNull);

    // ComboHeatBackground demo: tapping "Bump heat" cycles the displayed
    // heat percentage.
    final heatLabel = find.text('Heat: 0%');
    final bumpHeat = find.widgetWithText(CommonButton, 'Bump heat');
    for (var i = 0; i < 12 && heatLabel.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(heatLabel, findsOneWidget);
    await tester.ensureVisible(bumpHeat.last);
    await tester.pump();
    await tester.tap(bumpHeat.last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Heat: 25%'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'FEAT-141: prestige confirmation card confirms and cancels caller actions',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final open = find.byKey(const Key('openPrestigeCardBtn'));
      await tester.scrollUntilVisible(open, 350, scrollable: scrollable);
      await tester.ensureVisible(open);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(
        const Key('prestigeConfirmationShowcaseStatus'),
      );
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Prestige confirms: 0 · Keep playing: 0');

      // Test cancel (Keep Playing)
      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Prestige Confirmation'), findsOneWidget);
      expect(
        find.text('Requires Level 50 · Level 50 resets to 1'),
        findsOneWidget,
      );

      final cancelAction = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Keep Playing',
        ),
      );
      cancelAction.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(statusText(), 'Prestige confirms: 0 · Keep playing: 1');

      // Test confirm (Prestige Now)
      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 300));
      final confirmAction = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Prestige Now',
        ),
      );
      confirmAction.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(statusText(), 'Prestige confirms: 1 · Keep playing: 1');

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-144: streak shield modal uses shield and repair caller seams',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final open = find.byKey(const Key('openStreakShieldCardBtn'));
      await tester.scrollUntilVisible(open, 350, scrollable: scrollable);
      await tester.ensureVisible(open);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('streakShieldShowcaseStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Streak: 12 days · Shields: 1 · Repairs: 0');

      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Streak Protection'), findsOneWidget);
      expect(find.text('Use Shield'), findsOneWidget);

      tester
          .widget<NeonDialogButton>(
            find.byWidgetPredicate(
              (w) => w is NeonDialogButton && w.action.label == 'Use Shield',
            ),
          )
          .action
          .onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(statusText(), 'Streak: 13 days · Shields: 0 · Repairs: 0');

      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Repair Streak'), findsOneWidget);
      tester
          .widget<NeonDialogButton>(
            find.byWidgetPredicate(
              (w) => w is NeonDialogButton && w.action.label == 'Repair Streak',
            ),
          )
          .action
          .onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(statusText(), 'Streak: 13 days · Shields: 0 · Repairs: 1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-140: offline earnings popup counts up and caller owns collect/double',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final open = find.byKey(const Key('simulateOfflineReturnBtn'));
      await tester.scrollUntilVisible(open, 350, scrollable: scrollable);
      await tester.ensureVisible(open);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('offlineEarningsShowcaseStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Offline coins collected: 0 · Double seam calls: 0');

      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('offlineEarningsCoinCount')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('1,250'), findsWidgets);

      // Exercise caller-owned double seam through NeonDialog action callback.
      final doubleAction = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Double 2x',
        ),
      );
      doubleAction.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(statusText(), 'Offline coins collected: 0 · Double seam calls: 1');

      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 300));
      final collectAction = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Collect',
        ),
      );
      collectAction.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        statusText(),
        'Offline coins collected: 1250 · Double seam calls: 1',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-139: tiered leaderboard rows reflect score/rank update and reset',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final bump = find.byKey(const Key('tieredRankBumpBtn'));
      await tester.scrollUntilVisible(bump, 350, scrollable: scrollable);
      await tester.ensureVisible(bump);
      await tester.pump(const Duration(milliseconds: 100));

      TieredLeaderboardRow youRow() => tester.widget<TieredLeaderboardRow>(
        find
            .ancestor(
              of: find.text('RoyPlayer'),
              matching: find.byType(TieredLeaderboardRow),
            )
            .first,
      );

      final youBefore = youRow();
      expect(youBefore.rank, 2);
      expect(youBefore.score, '15420');

      await tester.tap(bump);
      await tester.pump(const Duration(milliseconds: 300));
      final youAfter = youRow();
      expect(youAfter.rank, 1);
      expect(youAfter.score, '15920');

      final reset = find.byKey(const Key('tieredRankResetBtn'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pump(const Duration(milliseconds: 300));
      final youReset = youRow();
      expect(youReset.rank, 2);
      expect(youReset.score, '15420');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-138: move hint consumes uses, switches to Get More and dismisses',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final open = find.byKey(const Key('openMoveHintBtn'));
      await tester.scrollUntilVisible(open, 350, scrollable: scrollable);
      await tester.ensureVisible(open);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('moveHintShowcaseStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Hints: 3 · Shown: 0 · Refills: 0 · none');

      // Consume three available hints; each dialog is dismissed through its
      // dialog action so the next modal opens only after the previous closes.
      for (var i = 0; i < 3; i++) {
        await tester.tap(open);
        await tester.pump(const Duration(milliseconds: 300));
        final action = tester.widget<CommonButton>(
          find.byKey(const ValueKey('moveHintActionBtn')),
        );
        action.onTap!.call();
        await tester.pump(const Duration(milliseconds: 300));
        final dismiss = tester.widget<NeonDialogButton>(
          find.byWidgetPredicate(
            (w) => w is NeonDialogButton && w.action.label == 'Got it',
          ),
        );
        dismiss.action.onTap();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
      }
      expect(statusText(), 'Hints: 0 · Shown: 3 · Refills: 0 · Dismissed');

      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Get More (+)'), findsWidgets);
      final getMore = tester.widget<CommonButton>(
        find.byKey(const ValueKey('moveHintActionBtn')),
      );
      getMore.onTap!.call();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        statusText(),
        'Hints: 0 · Shown: 3 · Refills: 1 · Refill requested',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-137: win streak advances multiplier tiers, info tap, and loss resets',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final win = find.byKey(const Key('winRoundBtn'));
      await tester.scrollUntilVisible(win, 350, scrollable: scrollable);
      await tester.ensureVisible(win);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('winStreakShowcaseStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Win streak: 0 · Info taps: 0');
      expect(find.text('x1'), findsWidgets);

      for (var i = 0; i < 3; i++) {
        await tester.tap(win);
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(statusText(), 'Win streak: 3 · Info taps: 0');
      expect(find.text('x2'), findsOneWidget);
      expect(find.text('3 wins'), findsOneWidget);

      final hud = find.byKey(const ValueKey('winStreakFlameTapTarget'));
      await tester.ensureVisible(hud);
      await tester.tap(hud);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Win streak: 3 · Info taps: 1');

      final lose = find.byKey(const Key('loseRoundBtn'));
      await tester.ensureVisible(lose);
      await tester.tap(lose);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Win streak: 0 · Info taps: 1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-136: weekly challenge advances, claims milestones and resets',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final addProgress = find.byKey(const Key('weeklyChallengeAddBtn'));
      await tester.scrollUntilVisible(addProgress, 350, scrollable: scrollable);
      await tester.ensureVisible(addProgress);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('weeklyChallengeShowcaseStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Weekly progress: 20 · Claims: 0');

      // Add 30 -> progress 50, unlock milestone 25. Claim through its milestone callback.
      await tester.tap(addProgress);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Weekly progress: 50 · Claims: 0');
      final tier1 = find.byKey(const ValueKey('weeklyChallengeClaim_0'));
      await tester.ensureVisible(tier1);
      await tester.tap(tier1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Weekly progress: 50 · Claims: 1');

      // Add 30 -> progress 80, unlock milestone 75; claim once.
      await tester.ensureVisible(addProgress);
      await tester.tap(addProgress);
      await tester.pump(const Duration(milliseconds: 100));
      final tier2 = find.byKey(const ValueKey('weeklyChallengeClaim_1'));
      await tester.ensureVisible(tier2);
      await tester.tap(tier2);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Weekly progress: 80 · Claims: 2');

      final reset = find.byKey(const Key('weeklyChallengeResetBtn'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Weekly progress: 20 · Claims: 0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-135: milestone dialog opens, claim updates caller status and closes',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final openBtn = find.byKey(const Key('openMilestoneBtn'));
      await tester.scrollUntilVisible(openBtn, 350, scrollable: scrollable);
      await tester.ensureVisible(openBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Milestone claimed: 0'), findsOneWidget);

      await tester.tap(openBtn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Milestone Reached!'), findsOneWidget);
      expect(find.text('Coins'), findsOneWidget);

      final claimButton = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Claim',
        ),
      );
      claimButton.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Milestone claimed: 1'), findsOneWidget);
      expect(find.text('Milestone Reached!'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-133: level path map renders winding nodes and invokes onLevelTap on unlocked node',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final status = find.byKey(const Key('levelPathMapStatus'));
      await tester.scrollUntilVisible(status, 350, scrollable: scrollable);
      await tester.ensureVisible(status);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Path Level selected: 0'), findsOneWidget);

      final level4Node = find.byKey(const ValueKey('levelPathNodeTap_4'));
      await tester.ensureVisible(level4Node);
      await tester.tap(level4Node);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Path Level selected: 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-134: star chest hud shows info, adds stars to fill, and opens chest',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final addStarsBtn = find.byKey(const Key('starChestAddStarsBtn'));
      await tester.scrollUntilVisible(addStarsBtn, 350, scrollable: scrollable);
      await tester.ensureVisible(addStarsBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('starChestShowcaseStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Star Chest status: none · Opened: 0');
      expect(find.text('15/20 ⭐'), findsOneWidget);

      // Tap when not ready -> calls onInfoTap
      final tapTarget = find.byKey(const ValueKey('starChestTapTarget'));
      await tester.ensureVisible(tapTarget);
      await tester.tap(tapTarget);
      await tester.pump();
      expect(statusText(), 'Star Chest status: Need 5 more stars · Opened: 0');

      // Add stars (+5) -> reaches 20/20, ready to open
      await tester.ensureVisible(addStarsBtn);
      await tester.tap(addStarsBtn);
      await tester.pump();
      expect(statusText(), 'Star Chest status: Earned 5 stars · Opened: 0');
      expect(find.byKey(const ValueKey('starChestOpenBadge')), findsOneWidget);

      // Tap when ready -> calls onOpenChestTap
      await tester.ensureVisible(tapTarget);
      await tester.tap(tapTarget);
      await tester.pump();
      expect(statusText(), 'Star Chest status: Opened Star Chest! · Opened: 1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-132: multiplier wheel stops needle, awards prize, and resets',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final stopBtn = find.byKey(const Key('multiplierWheelStopBtn'));
      await tester.scrollUntilVisible(stopBtn, 350, scrollable: scrollable);
      await tester.ensureVisible(stopBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('multiplierWheelStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Won multiplier: spinning · Prize: pending');

      await tester.tap(stopBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), contains('coins'));
      expect(statusText(), isNot(contains('spinning')));

      // Reset
      final resetBtn = find.byKey(const Key('multiplierWheelResetBtn'));
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Won multiplier: spinning · Prize: pending');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-129: booster slot bar taps ready booster, refills empty, and resets',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final refillHammerBtn = find.byKey(const Key('boosterRefillHammerBtn'));
      await tester.scrollUntilVisible(
        refillHammerBtn,
        350,
        scrollable: scrollable,
      );
      await tester.ensureVisible(refillHammerBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('boosterSlotStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Booster action: none · Hammer: 2 · Bomb: 0');

      // Tap ready Hammer slot
      final hammerTap = find.byKey(const ValueKey('boosterSlotTap_hammer'));
      await tester.ensureVisible(hammerTap);
      await tester.tap(hammerTap);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Booster action: Used hammer · Hammer: 1 · Bomb: 0');

      // Tap empty Bomb slot (refills +3)
      final bombTap = find.byKey(const ValueKey('boosterSlotTap_bomb'));
      await tester.ensureVisible(bombTap);
      await tester.tap(bombTap);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        statusText(),
        'Booster action: Refilled bomb (+3) · Hammer: 1 · Bomb: 3',
      );

      // Reset
      final resetBtn = find.byKey(const Key('boosterResetCountsBtn'));
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Booster action: none · Hammer: 2 · Bomb: 0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-130: season event banner advances progress and calls onTap',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final progressBtn = find.byKey(const Key('seasonEventProgressBtn'));
      await tester.scrollUntilVisible(progressBtn, 350, scrollable: scrollable);
      await tester.ensureVisible(progressBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('seasonEventStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Event taps: 0 · Ended: false · Progress: 45%');

      // Tap banner
      final banner = find.byType(SeasonEventBanner);
      await tester.ensureVisible(banner);
      await tester.tap(banner);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Event taps: 1 · Ended: false · Progress: 45%');

      // Add progress
      await tester.ensureVisible(progressBtn);
      await tester.tap(progressBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Event taps: 1 · Ended: false · Progress: 70%');

      // Reset
      final resetBtn = find.byKey(const Key('seasonEventResetBtn'));
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Event taps: 1 · Ended: false · Progress: 0%');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FEAT-131: tap hint toggles, switches gesture, never blocks tap',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final toggle = find.byKey(const Key('tapHintToggleBtn'));
      await tester.scrollUntilVisible(toggle, 350, scrollable: scrollable);
      await tester.ensureVisible(toggle);
      await tester.pump(const Duration(milliseconds: 100));

      final status = find.byKey(const Key('tapHintStatus'));
      String statusText() => tester.widget<Text>(status).data!;
      expect(statusText(), 'Hint: tap · Target taps: 0');
      expect(find.byKey(const ValueKey('tapHintHand')), findsOneWidget);

      await tester.tap(find.text('Tap me').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Hint: tap · Target taps: 1');

      await tester.tap(find.byKey(const Key('tapHintGestureBtn')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Hint: swipe · Target taps: 1');
      expect(find.byKey(const ValueKey('tapHintHand')), findsOneWidget);

      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 100));
      expect(statusText(), 'Hint: hidden · Target taps: 1');
      expect(find.byKey(const ValueKey('tapHintHand')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FEAT-128: combo meter fills, ranks up, and drops', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('widgetShowcaseList')),
          matching: find.byType(Scrollable),
        )
        .first;
    final add = find.byKey(const Key('comboMeterAddBtn'));
    await tester.scrollUntilVisible(add, 350, scrollable: scrollable);
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 100));

    final status = find.byKey(const Key('comboMeterStatus'));
    String statusText() => tester.widget<Text>(status).data!;
    expect(statusText(), 'Multiplier: x1 · Progress: 0%');

    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 100));
    expect(statusText(), 'Multiplier: x1 · Progress: 34%');

    await tester.tap(add);
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 100));
    expect(statusText(), 'Multiplier: x1 · Progress: 100%');

    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 100));
    expect(statusText(), 'Multiplier: x2 · Progress: 0%');
    expect(find.text('x2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('comboMeterResetBtn')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(statusText(), 'Multiplier: x1 · Progress: 0%');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'FEAT-124: upgrade tier then open chest reveals matching reward',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final upgrade = find.byKey(const Key('tieredChestUpgradeBtn'));
      await tester.scrollUntilVisible(upgrade, 350, scrollable: scrollable);
      await tester.ensureVisible(upgrade);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tier: Wood · Opened: false'), findsOneWidget);
      await tester.tap(upgrade);
      await tester.pump(const Duration(milliseconds: 220));
      expect(find.text('Tier: Silver · Opened: false'), findsOneWidget);

      final chest = find.byKey(const ValueKey('tieredChestTap'));
      await tester.ensureVisible(chest);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(chest);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Tier: Silver · Opened: true'), findsOneWidget);
      expect(find.text('Silver reward: 200 gems'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FEAT-127: flash sale buy increments caller-owned status', (
    tester,
  ) async {
    await _pumpShowcase(tester);

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('widgetShowcaseList')),
          matching: find.byType(Scrollable),
        )
        .first;
    final buy = find.byKey(const ValueKey('flashSaleBuyBtn'));
    await tester.scrollUntilVisible(buy, 300, scrollable: scrollable);
    await tester.ensureVisible(buy);
    await tester.pump();
    expect(find.text('Flash sale buys: 0 · Expired: false'), findsOneWidget);

    await tester.tap(buy);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Flash sale buys: 1 · Expired: false'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShopItemCard demo buy button shows a toast', (tester) async {
    await _pumpShowcase(tester);
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('widgetShowcaseList')),
          matching: find.byType(Scrollable),
        )
        .first;
    final sectionAnchor = find.text('Gems: 0');
    await tester.scrollUntilVisible(sectionAnchor, 300, scrollable: scrollable);
    final offer = find.text(r'$0.99');
    await tester.ensureVisible(offer.first);
    await tester.pump();

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

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final gemsStatus = find.text('Gems: 0');
      await tester.scrollUntilVisible(gemsStatus, 300, scrollable: scrollable);
      expect(gemsStatus, findsOneWidget);
      final firstGemOffer = find.text(r'$0.99').first;
      await tester.scrollUntilVisible(
        firstGemOffer,
        300,
        scrollable: scrollable,
      );
      await tester.ensureVisible(firstGemOffer);
      await tester.pump();
      await tester.tap(find.text(r'$0.99').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Gems: 100'), findsOneWidget);
      // Let this toast's full lifecycle (2s hold + reverse animation)
      // finish before triggering another — 2 concurrent ToastBanner
      // AnimationControllers under fake-async triggers an unrelated
      // Flutter framework assertion, not a bug in this demo's own code.
      await tester.pump(const Duration(seconds: 3));

      final secondGemOffer = find.text(r'$4.99').first;
      await tester.scrollUntilVisible(
        secondGemOffer,
        300,
        scrollable: scrollable,
      );
      await tester.ensureVisible(secondGemOffer);
      await tester.pump();
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

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final sectionAnchor = find.text('Gems: 0');
      await tester.scrollUntilVisible(
        sectionAnchor,
        300,
        scrollable: scrollable,
      );
      final removeAdsOffer = find.text(r'$2.99');
      expect(removeAdsOffer, findsWidgets);
      expect(find.text('Owned'), findsNothing);

      await tester.ensureVisible(removeAdsOffer.first);
      await tester.pump();
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

  testWidgets(
    'BUG-88: reward pipeline persist failure inside a live widget tree '
    'rolls back — gem display stays at the last actually-persisted value, '
    'no ghost balance, no crash',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final failing = _ThrowingOnKeyStorage(
        await SharedPreferences.getInstance(),
        StorageKeys.rewardTransactionPipelineV1,
      );
      Get.put<StorageService>(failing);

      await _pumpShowcase(tester);

      // The showcase screen's own initState registers a REAL
      // RewardTransactionPipeline (permanent, via `.maybe ?? Get.put(...)`)
      // wired to `StorageService.to` — this is the exact live instance the
      // pumped widget tree reads from, not a separately constructed one.
      final pipeline = RewardTransactionPipeline.maybe;
      expect(pipeline, isNotNull);

      final result = await pipeline!.grant(
        source: RewardSource.ad,
        transactionId: 'widget_test_bug88',
        lines: const [RewardLine(currency: 'gem', amount: 999)],
      );

      expect(
        result,
        isA<SdkFailure<RewardTransactionRecord>>(),
        reason: 'rewardTransactionPipelineV1 writes are forced to throw',
      );
      expect(
        pipeline.auditTrail,
        isEmpty,
        reason: 'a failed persist must not leave a ghost record in memory',
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Unlock gems: 0'),
        findsOneWidget,
        reason:
            'gem balance in the live widget tree must NOT reflect a '
            'grant whose persist failed and was rolled back',
      );
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

  testWidgets(
    'FEAT-126: EnergyBar refill (+) invokes caller action and updates status',
    (tester) async {
      await _pumpShowcase(tester);

      final refill = find.byKey(const ValueKey('energyBarRefillBtn'));
      await tester.scrollUntilVisible(
        refill,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('widgetShowcaseList')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(refill);
      await tester.pump();
      expect(find.text('Refills: 0'), findsOneWidget);

      await tester.tap(refill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Refills: 1'), findsOneWidget);
      expect(find.text('∞'), findsWidgets);
      expect(find.byKey(const ValueKey('energyBarRefillBtn')), findsNothing);
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
      expect(find.text('Wheel ticks: 0'), findsOneWidget);

      await tester.tap(find.text('Spin').last);
      // Default spinDuration is 3s — several smaller pumps (not one big
      // jump) let the AnimationController's whenComplete() actually fire.
      await _settle(tester, steps: 20, stepMs: 200);

      expect(find.textContaining('Landed on'), findsOneWidget);
      final tickLabel = tester
          .widget<Text>(find.byKey(const Key('wheelTickStatus')))
          .data!;
      expect(tickLabel, matches(RegExp(r'Wheel ticks: [1-9]')));
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
      'LevelGoalTracker: collect action advances and completes goal',
      (tester) async {
        await _pumpShowcase(tester);

        final strawberries = find.byKey(
          const ValueKey('goalChip_strawberries'),
        );
        await tester.scrollUntilVisible(
          strawberries,
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(strawberries);
        await tester.pump(const Duration(milliseconds: 100));

        final goalSemantics = tester.getSemantics(strawberries);
        expect(goalSemantics.label, 'Strawberries: 7 remaining');
        expect(
          find.byKey(const ValueKey('goalRemaining_strawberries')),
          findsOneWidget,
        );

        final collect = find.byKey(const Key('bumpLevelGoalBtn'));
        await tester.ensureVisible(collect);
        for (var i = 0; i < 7; i++) {
          await tester.tap(collect);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          find.byKey(const ValueKey('goalCheck_strawberries')),
          findsOneWidget,
        );
        final checkmark = tester.widget<AnimatedScale>(
          find.ancestor(
            of: find.byKey(const ValueKey('goalCheck_strawberries')),
            matching: find.byType(AnimatedScale),
          ),
        );
        expect(checkmark.scale, 1.0);
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
      await tester.tap(
        find.widgetWithText(CommonButton, 'Simulate async').last,
        warnIfMissed: false,
      );
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
    'FEAT-143: SaveSlotPicker selects, creates, and confirms deletion through caller state',
    (tester) async {
      await _pumpShowcase(tester);

      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('widgetShowcaseList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final create = find.byKey(const ValueKey('saveSlotCreateBtn'));
      await tester.scrollUntilVisible(create, 350, scrollable: scrollable);
      await tester.ensureVisible(create);
      await tester.pump(const Duration(milliseconds: 100));

      Finder inPicker(Finder m) =>
          find.descendant(of: find.byType(SaveSlotPicker), matching: m);

      expect(inPicker(find.text('Warrior Arthur')), findsOneWidget);
      expect(inPicker(find.text('ACTIVE')), findsOneWidget);

      // Select inactive slot
      await tester.tap(
        find.byKey(const ValueKey('saveSlotSelectBtn_picker_slot_mage')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('saveSlotSelectBtn_picker_slot_warrior')),
        findsOneWidget,
      );

      // Create third slot -> hits maxSlots (3), create disabled
      await tester.tap(create);
      await tester.pump(const Duration(milliseconds: 100));
      expect(inPicker(find.text('Hero 3')), findsOneWidget);
      expect(tester.widget<CommonButton>(create).onTap, isNull);

      // Delete cancel keeps slot
      await tester.tap(
        find.byKey(const ValueKey('saveSlotDeleteBtn_picker_slot_3')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Delete Save Slot?'), findsOneWidget);
      tester
          .widget<NeonDialogButton>(
            find.byWidgetPredicate(
              (w) => w is NeonDialogButton && w.action.label == 'Cancel',
            ),
          )
          .action
          .onTap();
      await _settle(tester);
      expect(inPicker(find.text('Hero 3')), findsOneWidget);

      // Delete confirm removes slot and re-enables create
      await tester.tap(
        find.byKey(const ValueKey('saveSlotDeleteBtn_picker_slot_3')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester
          .widget<NeonDialogButton>(
            find.byWidgetPredicate(
              (w) => w is NeonDialogButton && w.action.label == 'Delete',
            ),
          )
          .action
          .onTap();
      await _settle(tester);
      expect(inPicker(find.text('Hero 3')), findsNothing);
      expect(tester.widget<CommonButton>(create).onTap, isNotNull);
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
      expect(find.textContaining('• Active'), findsOneWidget);

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

    testWidgets('"Start 12s cooldown": remains near 12s after fake-time pump', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Start 12s cooldown').last);
      await tester.pump();

      expect(find.text(fmtDur(const Duration(seconds: 12))), findsOneWidget);

      // `CooldownCountdownChip` targets DateTime.now(), not FakeAsync time;
      // a long tester.pump must not be mistaken for elapsed wall-clock time.
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('00:1'), findsWidgets);
      expect(find.text('00:09'), findsNothing);
      expect(tester.takeException(), isNull);
    });

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

  group('FEAT-98: PrivacyAwareAnalyticsQueue demo', () {
    testWidgets(
      'valid/PII queue, schema reject, failed flush retain, success clear',
      (tester) async {
        await _pumpShowcase(tester);
        expect(
          find.text('Analytics queue — Pending: 0 · Dropped: 0 · Uploaded: 0'),
          findsOneWidget,
        );

        await tester.tap(find.text('Grant analytics').last);
        await tester.pump();
        await tester.tap(find.text('Queue valid + PII').last);
        await tester.pump();
        expect(
          find.textContaining('Analytics queue — Pending: 1'),
          findsOneWidget,
        );
        expect(
          StorageService.to.getString(StorageKeys.analyticsQueueV1),
          isNot(contains('redacted@example.com')),
        );

        await tester.tap(find.text('Queue rejected').last);
        await tester.pump();
        expect(find.textContaining('Pending: 1 · Dropped: 1'), findsOneWidget);
        expect(
          StorageService.to.getString(StorageKeys.analyticsQueueV1),
          isNot(contains('never-persisted@example.com')),
        );

        await tester.tap(find.text('Flush fail').last);
        await tester.pump();
        expect(
          find.textContaining('Analytics queue — Pending: 1'),
          findsOneWidget,
        );

        await tester.tap(find.text('Flush success').last);
        await tester.pump();
        expect(
          find.text('Analytics queue — Pending: 0 · Dropped: 1 · Uploaded: 1'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('revoke consent purges pending queue and persisted payload', (
      tester,
    ) async {
      await _pumpShowcase(tester);
      await tester.tap(find.text('Grant analytics').last);
      await tester.pump();
      await tester.tap(find.text('Queue valid + PII').last);
      await tester.pump();
      expect(
        find.textContaining('Analytics queue — Pending: 1'),
        findsOneWidget,
      );

      await tester.tap(find.text('Revoke + purge').last);
      await tester.pump();

      expect(
        find.textContaining('Analytics queue — Pending: 0'),
        findsOneWidget,
      );
      expect(StorageService.to.getString(StorageKeys.analyticsQueueV1), isNull);
      expect(tester.takeException(), isNull);
    });
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

        expect(find.textContaining('Queue: 0 pending, 1 ran'), findsOneWidget);
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

    testWidgets('bấm "Simulate again (duplicate)" ngay sau: bị dedupe', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Simulate link').last);
      await tester.pump();
      await tester.tap(find.text('Simulate again (duplicate)').last);
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
    test('source thật: cả 4 vị trí (_inventoryGrant, _inventoryConsume, 2 chỗ '
        'deep-link) có "if (!mounted) return;" ngay trước setState', () {
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
    });

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
              .state<_GuardedAsyncWidgetState>(find.byType(_GuardedAsyncWidget))
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

      expect(find.text('App content (demo)'), findsOneWidget);
      expect(find.text('Update now'), findsNothing);
    });

    testWidgets('cycle sang soft: hiện overlay + nút Để sau, dismiss được', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Scenario: ok (tap to change)').last);
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
          find.text('Analytics context: {} (no analytics consent)'),
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
      'BUG-93: asset session được Get.put với tag riêng -> onInit đăng ký '
      'lifecycle hook thật; background pause, resumed chạy lại, dispose '
      'Get.delete đúng tag (không manual onClose/double-free)',
      (tester) async {
        final lifecycle = RoyLifecycleCoordinator();
        Get.put(lifecycle, permanent: true);

        await _pumpShowcase(tester);
        const tag = 'widget-showcase-asset-session';
        expect(Get.isRegistered<GameSessionController>(tag: tag), isTrue);
        final session = Get.find<GameSessionController>(tag: tag);
        expect(session.initialized, isTrue);

        await tester.tap(find.widgetWithText(CommonButton, 'Preload OK').first);
        await tester.pump(const Duration(milliseconds: 800));
        expect(session.snapshot.value.phase, GameSessionPhase.playing);

        lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
        await tester.pump(const Duration(milliseconds: 100));
        expect(session.snapshot.value.phase, GameSessionPhase.paused);

        lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 100));
        expect(session.snapshot.value.phase, GameSessionPhase.playing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(Get.isRegistered<GameSessionController>(tag: tag), isFalse);
        expect(session.isClosed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

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
        expect(find.textContaining('Preload OK — scene ready'), findsOneWidget);
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
        expect(find.textContaining('Preload OK — scene ready'), findsOneWidget);
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

      expect(find.textContaining('Scene unloaded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-58/FEAT-105: SceneTransitionOverlay demo', () {
    testWidgets('selecting Iris/Star/Diamond updates wipe shape', (
      tester,
    ) async {
      await _pumpShowcase(tester);
      for (final shape in [
        SceneWipeShape.iris,
        SceneWipeShape.star,
        SceneWipeShape.diamond,
      ]) {
        await tester.tap(find.byKey(Key('sceneWipeShape_${shape.name}')));
        await tester.pump();
        final overlay = tester.widget<SceneTransitionOverlay>(
          find.byType(SceneTransitionOverlay),
        );
        expect(overlay.wipeShape, shape);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'bấm "Switch scene (OK)": phase quay lại idle, Scene revision tăng',
      (tester) async {
        await _pumpShowcase(tester);

        expect(find.text('Scene #1'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(CommonButton, 'Switch scene (OK)').first,
        );
        // covering(260ms) + loading(delay 300ms trong load) + revealing(220ms).
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.text('Phase: idle'), findsOneWidget);
        expect(find.text('Scene #2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm "Switch scene (fail)": phase error hiện RetryErrorState, không tăng revision',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Switch scene (fail)').first,
        );
        await tester.pump(const Duration(milliseconds: 900));

        expect(find.text('Phase: error'), findsOneWidget);
        expect(find.text('Scene #1'), findsOneWidget);
        expect(
          find.textContaining('Could not load the new scene'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bấm "Cancel" giữa chừng: phase về idle ngay, không throw', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(
        find.widgetWithText(CommonButton, 'Switch scene (OK)').first,
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

      expect(find.text('(empty)'), findsOneWidget);
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

  group('FEAT-96: Preview & claim reward demo', () {
    testWidgets(
      'tap Preview & claim -> dialog hiện đúng nội dung -> confirm -> gem '
      'và potion đều tăng đúng',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Preview & claim reward').first,
        );
        await _settle(tester);

        expect(find.text('Claim reward?'), findsOneWidget);
        expect(
          find.text('You will receive +15 gem and +1 potion.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Claim reward now'));
        await _settle(tester);

        expect(find.text('Claim reward?'), findsNothing);
        expect(
          find.textContaining('Claimed +15 gem, +1 potion'),
          findsOneWidget,
        );
        expect(find.text('potion x1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'preview rồi CANCEL dialog -> không claim gì cả, state không đổi',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Preview & claim reward').first,
        );
        await _settle(tester);
        expect(find.text('Claim reward?'), findsOneWidget);

        await tester.tap(find.text('Not now'));
        await _settle(tester);

        expect(find.text('Claim reward?'), findsNothing);
        expect(find.textContaining('Claimed'), findsNothing);
        expect(find.text('(empty)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'plan preview từ trước, inventory bị lấp đầy qua UI SAU preview -> '
      'executePlan trên chính live pipeline/inventory instance của màn '
      'hình trả lỗi stale (conflict), không claim một phần',
      (tester) async {
        await _pumpShowcase(tester);

        // Lấy đúng live instance màn hình đang dùng (được Get.put permanent
        // trong initState) — preview một plan y hệt nút demo tự tạo.
        final pipeline = Get.find<RewardTransactionPipeline>();
        final preview = pipeline.preview(
          source: RewardSource.other,
          transactionId: 'widget_test_stale_plan',
          currencyLines: const [RewardLine(currency: 'gem', amount: 15)],
          itemLines: const [InventoryLine(itemId: 'potion', quantity: 1)],
        );
        final plan = (preview as SdkSuccess<RewardPlan>).value;

        // Lấp đầy capacity (4) qua UI thật ("Grant sword" — maxStack mặc
        // định 1, mỗi tap chiếm 1 slot mới) — plan đã preview ở trên giờ
        // stale vì inventory snapshot đã đổi.
        for (var i = 0; i < 4; i++) {
          await tester.tap(
            find.widgetWithText(CommonButton, 'Grant sword').first,
          );
          await _settle(tester);
        }
        expect(find.textContaining('Granted 1 x sword'), findsOneWidget);

        final result = await pipeline.executePlan(plan);

        expect(result, isA<SdkFailure<RewardTransactionRecord>>());
        expect(
          (result as SdkFailure<RewardTransactionRecord>).kind,
          SdkErrorKind.conflict,
        );
        expect(tester.takeException(), isNull);
      },
    );
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

    testWidgets(
      // BUG-63: outbox auto-drains when its `connectivity` coordinator
      // transitions to online (see offline_outbox_service.dart onInit) —
      // this only fires if the REOPENED screen's outbox is genuinely
      // subscribed to the REOPENED screen's own coordinator, not a stale
      // one reused from the first open (whose stream BUG-62's fix now
      // closes on screen close, silently killing that subscription).
      'mở lại screen (reopen): outbox mới tự drain đúng khi connectivity '
      'của LẦN MỞ MỚI chuyển online, không kẹt vào coordinator cũ (BUG-63)',
      (tester) async {
        await _pumpShowcase(tester);
        ConnectivityCoordinator.maybe?.onClose();

        // "Đóng" screen thật rồi "mở lại" (State hoàn toàn mới) — cùng kỹ
        // thuật đã dùng cho BUG-62.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await _pumpShowcase(tester);

        await tester.tap(find.widgetWithText(CommonButton, 'Enqueue OK').first);
        await tester.pump();
        expect(find.text('Pending: 1  · Manual review: 0'), findsOneWidget);

        // KHÔNG bấm "Drain now" thủ công — chỉ bật interface (Connectivity
        // demo) để kích hoạt auto-drain qua đúng coordinator của lần mở lại.
        await tester.tap(find.text('Interface up').last);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Pending: 0  · Manual review: 0'), findsOneWidget);
        expect(tester.takeException(), isNull);

        ConnectivityCoordinator.maybe?.onClose();
      },
    );
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

    testWidgets('bấm "Show debug bounds" bọc slot bằng DecoratedBox viền', (
      tester,
    ) async {
      await _pumpShowcase(tester);

      await tester.tap(find.text('Show debug bounds'));
      await tester.pump();

      expect(find.text('Hide debug bounds'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ENH-90: rescheduleEnergyReminder / rescheduleStreakReminder demo', () {
    late _RecordingReminderService reminder;

    setUp(() {
      reminder = _RecordingReminderService();
      Get.put<ReminderService>(reminder, permanent: true);
    });

    testWidgets(
      'năng lượng chưa đầy -> bấm nút hiện đúng delay tính được, không '
      'phải "đã huỷ"',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(find.text('Consume 1 energy').last);
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(
          find.widgetWithText(CommonButton, 'Reschedule energy reminder').first,
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('Reminder set in'), findsOneWidget);
        expect(reminder.scheduled.map((c) => c.id), [
          kEnergyReminderNotificationId,
        ]);
        expect(reminder.scheduled.single.delay, greaterThan(Duration.zero));
        expect(reminder.cancelled, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'năng lượng đầy sẵn (chưa tiêu gì) -> bấm nút hiện đúng "đã huỷ"',
      (tester) async {
        await _pumpShowcase(tester);

        await tester.tap(
          find.widgetWithText(CommonButton, 'Reschedule energy reminder').first,
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('Reminder cancelled'), findsOneWidget);
        expect(reminder.cancelled, [kEnergyReminderNotificationId]);
        expect(reminder.scheduled, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('chưa claim hôm nay -> bấm nút streak reminder hiện đúng delay '
        'tính được', (tester) async {
      await _pumpShowcase(tester);

      await tester.tap(
        find.widgetWithText(CommonButton, 'Reschedule streak reminder').first,
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Reminder set in'), findsOneWidget);
      expect(reminder.scheduled.map((c) => c.id), [
        kStreakReminderNotificationId,
      ]);
      expect(reminder.scheduled.single.delay, greaterThan(Duration.zero));
      expect(reminder.cancelled, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'đã claim hôm nay -> bấm nút streak reminder hiện đúng "đã huỷ"',
      (tester) async {
        await _pumpShowcase(tester);

        // Claim hôm nay bằng cách tap đúng ngày 1 trong
        // DailyLoginCalendarWidget — cùng cách test demo widget đó đã dùng.
        final calendar = find.byType(DailyLoginCalendarWidget);
        await tester.tap(
          find.descendant(of: calendar, matching: find.text('1')),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(
          find.widgetWithText(CommonButton, 'Reschedule streak reminder').first,
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('Reminder cancelled'), findsOneWidget);
        expect(reminder.cancelled, [kStreakReminderNotificationId]);
        expect(reminder.scheduled, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'Wave 1 P0: CandySlider, ItemFlyOverlay, RewardSequenceCoordinator demos',
    () {
      testWidgets('CandySlider demo renders and responds to drag', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final slider = find.byType(CandySlider);
        expect(slider, findsOneWidget);
        await tester.drag(slider, const Offset(50, 0));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'ItemFlyOverlay demo: tapping Fly items inserts overlay without throwing',
        (tester) async {
          await _pumpShowcase(tester);
          final flyButton = find
              .widgetWithText(CommonButton, 'Fly items')
              .first;
          expect(flyButton, findsOneWidget);
          await tester.tap(flyButton);
          await tester.pump();
          expect(find.byType(ItemFlyOverlay), findsOneWidget);
          // The overlay creates its AnimationController after the insertion frame;
          // prime its ticker, then advance past 4*550ms + 3*70ms flight timeline.
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 3000));
          await tester
              .pump(); // OverlayEntry removal rebuilds Overlay on next frame.
          expect(find.byType(ItemFlyOverlay), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'RewardSequenceCoordinator demo displays banner and content',
        (tester) async {
          await _pumpShowcase(tester);
          expect(find.byType(RewardSequenceCoordinator), findsOneWidget);
          expect(find.text('Stage Clear!'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('3 Stars Earned'), findsOneWidget);
          expect(
            find.widgetWithText(CommonButton, 'Claim All').first,
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('FEAT-106 showcase reuses its 50 particle pool', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final demo = find.byKey(const Key('pooledParticleBurstDemo'));
        final burst = find.descendant(
          of: demo,
          matching: find.byType(PooledParticleBurst),
        );
        expect(burst, findsOneWidget);
        final state = tester.state<PooledParticleBurstState>(burst);
        expect(state.totalCreated, 50);
        final button = find.descendant(
          of: demo,
          matching: find.widgetWithText(CommonButton, 'Burst 50 particles'),
        );

        for (var i = 0; i < 3; i++) {
          await tester.tap(button);
          await tester.pump();
          expect(state.activeCount, 50);
          await tester.pump(const Duration(milliseconds: 1200));
          await tester.pump();
          expect(state.activeCount, 0);
          expect(state.totalCreated, 50);
        }
        expect(state.freeCount, 50);
        expect(find.text('Completed: 3 · Objects created: 50'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-107 JuicyFeedback showcases six preset actions', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final tapButton = find.widgetWithText(CommonButton, 'tap');
        for (var i = 0; i < 40 && tapButton.evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 100));
        }
        for (final preset in JuicyPreset.values) {
          expect(
            find.widgetWithText(CommonButton, preset.name),
            findsOneWidget,
          );
        }
        await tester.tap(tapButton.first);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-118 radial menu opens and invokes action', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final menu = find.byType(RadialActionMenu);
        await tester.ensureVisible(menu);
        await tester.pump();
        final primary = find.byKey(const ValueKey('radialActionPrimary'));
        await tester.tap(primary);
        await tester.pump(const Duration(milliseconds: 300));
        final share = find.byKey(const ValueKey('radialAction_0_Share'));
        expect(share, findsOneWidget);
        tester.widget<CommonButton>(share).onTap!();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Last action: Share'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-123 repairs streak through caller callback', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final open = find.byKey(const Key('openStreakRepairShowcase'));
        await tester.scrollUntilVisible(
          open,
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('widgetShowcaseList')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('14-day streak'), findsOneWidget);
        final repairButton = tester.widget<NeonDialogButton>(
          find.byWidgetPredicate(
            (w) =>
                w is NeonDialogButton && w.action.label == 'Repair (20 gems)',
          ),
        );
        repairButton.action.onTap();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.text('Streaks repaired: 1'), findsOneWidget);
        expect(find.text('Streak Lost!'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-121 emoji burst caps, rises and cleans up', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final demo = find.byType(FloatingEmojiBurst);
        await tester.scrollUntilVisible(
          demo,
          350,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('widgetShowcaseList')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final heart = find.byKey(const ValueKey('emojiButton_❤️'));
        await tester.ensureVisible(heart);
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await tester.tap(heart);
          await tester.pump(const Duration(milliseconds: 100));
        }
        final floating = find.descendant(of: demo, matching: find.text('❤️'));
        expect(floating, findsNWidgets(5));
        await tester.pump(const Duration(seconds: 2));
        expect(floating, findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-120 stacked avatar group caps and taps overflow', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final group = find.byKey(const Key('stackedAvatarDemo'));
        await tester.scrollUntilVisible(
          group,
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('widgetShowcaseList')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('+3'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stackedAvatarOverflow')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Avatar group: Opened 3 more'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-119 reveals then explicitly invokes swipe action', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final tile = find.byKey(const Key('swipeActionDemo'));
        await tester.ensureVisible(tile);
        await tester.drag(tile, const Offset(180, 0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('swipeAction_Claim')), findsOneWidget);
        expect(find.text('Swipe action: Claimed'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('swipeAction_Claim')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Swipe action: Claimed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-116 search debounce, clear and filters work', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final search = find.byType(CandySearchBar);
        await tester.ensureVisible(search);
        await tester.enterText(
          find.descendant(of: search, matching: find.byType(TextFormField)),
          'gem',
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Search: gem'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('candySearchClear')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Search:  ·'), findsOneWidget);
        await tester.tap(find.text('Rare'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('Filters: rare'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-115 staggered grid showcases six tappable tiles', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final lastTile = find.byKey(const ValueKey('staggeredGridTile_5'));
        await tester.scrollUntilVisible(
          lastTile,
          400,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('widgetShowcaseList')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        for (var i = 0; i < 6; i++) {
          expect(find.byKey(ValueKey('staggeredGridTile_$i')), findsOneWidget);
        }
        await tester.pump(const Duration(milliseconds: 900));
        await tester.ensureVisible(lastTile);
        await tester.pump();
        await tester.tap(lastTile);
        await tester.pump();
        expect(find.text('Tapped: 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-114 opens three panels in sequence', (tester) async {
        await _pumpShowcase(tester);
        for (final header in [
          'How do I earn more coins?',
          'More details 1',
          'More details 2',
        ]) {
          final title = find.text(header);
          await tester.ensureVisible(title);
          await tester.tap(title);
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(
          find.text(
            'Win levels and collect daily rewards to fill your wallet.',
          ),
          findsOneWidget,
        );
        expect(find.text('Additional help topic 1.'), findsOneWidget);
        expect(find.text('Additional help topic 2.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-113 radio and checkbox update caller state', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final radio = find.text('Relaxed mode');
        await tester.scrollUntilVisible(
          radio,
          350,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('widgetShowcaseList')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(radio);
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Mode: Relaxed · Hints: off'), findsOneWidget);
        await tester.tap(find.text('Enable extra hints'));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Mode: Relaxed · Hints: on'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-112 scratch card reveals caller-owned prize status', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final scratch = find.byType(ScratchCard);
        await tester.scrollUntilVisible(
          scratch,
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('widgetShowcaseList')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final rect = tester.getRect(scratch.first);
        final gesture = await tester.startGesture(
          rect.topLeft + const Offset(10, 10),
        );
        for (final lane in [10.0, 48.0, 86.0, 124.0]) {
          await gesture.moveTo(Offset(rect.left + 10, rect.top + lane));
          for (var step = 1; step <= 10; step++) {
            await gesture.moveTo(
              Offset(rect.left + 10 + step * 25, rect.top + lane),
            );
          }
        }
        await gesture.up();
        await tester.pump();
        expect(find.text('Prize revealed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-111 piggy bank unlocks, fills and breaks', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        await tester.tap(find.byKey(const Key('piggyBankUnlock')));
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.tap(find.byKey(const Key('piggyBankAddWinCoins')));
          await tester.pump();
        }
        expect(find.text('1000 / 1000 coins'), findsOneWidget);
        expect(find.byKey(const Key('piggyBankBreak')), findsOneWidget);
        var peakScale = 1.0;
        for (var i = 0; i < 9; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final scale = tester
              .widget<Transform>(
                find.byKey(const ValueKey('piggyBankPulseTransform')),
              )
              .transform
              .entry(0, 0);
          if (scale > peakScale) peakScale = scale;
        }
        expect(peakScale, greaterThan(1));
        await tester.tap(find.byKey(const Key('piggyBankBreak')));
        await tester.pump();
        expect(find.text('0 / 1000 coins'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-110 MysteryChest showcase reveals caller reward', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final chest = find.byType(MysteryChestOpening).first;
        await tester.scrollUntilVisible(
          chest,
          400,
          scrollable: find
              .ancestor(of: chest, matching: find.byType(Scrollable))
              .first,
        );
        final chestState = tester.state<MysteryChestOpeningState>(chest);
        final gesture = await tester.startGesture(tester.getCenter(chest));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        expect(chestState.isAnimating, isTrue);
        await tester.pump(const Duration(milliseconds: 1700));
        expect(chestState.phase, MysteryChestPhase.revealed);
        expect(find.text('Reward revealed: +500 coins'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-109 demo lazily scrolls full 30 milestone road', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final road = find.byType(BattlePassRoad);
        expect(road, findsOneWidget);
        expect(
          find.byKey(const ValueKey('battlePassMilestone_tier_5')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('battlePassMilestone_tier_30')),
          findsNothing,
        );

        final target = find.byKey(
          const ValueKey('battlePassMilestone_tier_30'),
        );
        final roadScroll = find.descendant(
          of: road,
          matching: find.byType(Scrollable),
        );
        expect(roadScroll, findsOneWidget);
        await tester.scrollUntilVisible(target, 300, scrollable: roadScroll);
        expect(target, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-109 claims free and VIP rewards through pipeline', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final wallet = Get.find<EconomyWallet>();
        final coinsBefore = wallet.balanceOf('coin');
        final gemsBefore = wallet.balanceOf('gem');
        final freeClaim = find.byKey(
          const ValueKey('battlePassClaim_tier_5_free'),
        );
        expect(freeClaim, findsOneWidget);
        await tester.tap(freeClaim);
        await tester.pump(const Duration(milliseconds: 100));
        expect(freeClaim, findsNothing);
        expect(wallet.balanceOf('coin'), coinsBefore + 250);

        await tester.tap(find.widgetWithText(CommonButton, 'Enable VIP'));
        await tester.pump();
        expect(
          tester.widget<BattlePassRoad>(find.byType(BattlePassRoad)).vipEnabled,
          isTrue,
        );
        final vipClaim = find.byKey(
          const ValueKey('battlePassClaim_tier_5_vip'),
        );
        expect(vipClaim, findsOneWidget);
        await tester.tap(vipClaim);
        await tester.pump(const Duration(milliseconds: 100));
        expect(vipClaim, findsNothing);
        expect(wallet.balanceOf('gem'), gemsBefore + 10);
        expect(tester.takeException(), isNull);
      });

      testWidgets('FEAT-108 GoldenShimmerText showcase renders jackpot', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final jackpot = find.byType(GoldenShimmerText);
        expect(jackpot, findsOneWidget);
        expect(find.text('JACKPOT 1,000,000'), findsWidgets);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      });

      testWidgets('ENH-101 showcase mounts pulsing/radar BadgeDot', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        expect(find.byType(BadgeDot), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 750));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'ENH-99 victory card stars pop sequentially with status callbacks',
        (tester) async {
          await _pumpShowcase(tester);
          final status = find.byKey(const Key('victoryStarBurstStatus'));
          expect(status, findsOneWidget);
          expect(tester.widget<Text>(status).data, startsWith('Star burst:'));

          await tester.pump();
          expect(find.text('Star burst: 0'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.text('Star burst: 0, 1'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.text('Star burst: 0, 1, 2'), findsOneWidget);

          final replay = find.widgetWithText(CommonButton, 'Replay star burst');
          await tester.tap(replay);
          await tester.pump();
          expect(tester.widget<Text>(status).data, startsWith('Star burst:'));
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 550));
          expect(tester.widget<Text>(status).data, 'Star burst: 0, 1, 2');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('ENH-100 RewardPopup demo uses spring entrance', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        final trigger = find.widgetWithText(CommonButton, 'Show reward').first;
        await tester.tap(trigger);
        await tester.pump();

        final popup = find.byType(RewardPopup);
        expect(popup, findsOneWidget);
        final spring = find.descendant(
          of: popup,
          matching: find.byType(SpringScaleTransition),
        );
        expect(spring, findsOneWidget);
        expect(
          tester.widget<SpringScaleTransition>(spring).controller.isAnimating,
          isTrue,
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          tester.widget<SpringScaleTransition>(spring).controller.value,
          1,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('CardFlip3D demo renders and flips on reveal button tap', (
        tester,
      ) async {
        await _pumpShowcase(tester);
        expect(find.byType(CardFlip3D), findsOneWidget);
        expect(find.text('Tap to reveal'), findsOneWidget);

        final revealBtn = find
            .widgetWithText(CommonButton, 'Reveal card')
            .first;
        await tester.tap(revealBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 400)); // gleam

        expect(find.text('SSR HERO!'), findsOneWidget);
        expect(find.text('Flip back'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );
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

/// Ghi lại lời gọi thay vì chạm plugin thông báo thật: plugin chưa được nạp
/// trong widget test nên `ReminderService` thật ném `LateInitializationError`
/// (bị nuốt, chỉ in log) và test không kiểm được gì về lời gọi.
class _RecordingReminderService extends ReminderService {
  final scheduled = <({int id, Duration delay})>[];
  final cancelled = <int>[];

  @override
  Future<void> scheduleNext({
    Duration delay = const Duration(hours: 24),
    String title = 'Roy Project Base Game',
    String body = 'Come back and play!',
    int id = 0,
  }) async => scheduled.add((id: id, delay: delay));

  @override
  Future<void> cancel({int id = 0}) async => cancelled.add(id);
}
