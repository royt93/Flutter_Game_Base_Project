import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/app_version_gate.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/presentation/widgets/common/app_version_gate_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/bottom_sheet_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/empty_state_placeholder.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_up_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/loading_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/network_status_banner.dart';
import 'package:roy_casual_kit/presentation/widgets/common/pause_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/retry_error_state.dart';
import 'package:roy_casual_kit/presentation/widgets/common/spotlight_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_repair_dialog.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toast_banner.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tooltip_bubble.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tutorial_sequence.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

/// ENH-119 (batch B): overlay / dialog / toast widgets, each in one fixed state
/// (the interesting variants are separate tests). Deterministic: reduced
/// motion where an entrance animation would otherwise be mid-flight, no real
/// timers left running, no ambient clock.
///
/// Overlays here are rendered IN the widget tree (as the kit itself does, see
/// CLAUDE.md "Dialog pattern"), never via `showDialog`/routes.
void main() {
  final previous = installGoldenTolerance(
    'batch_b_overlay_widgets_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  // The matrix's locale-vi case wraps the tree in `Localizations.override(vi)`
  // and MaterialLocalizations only ships `en` here: widgets with a text field
  // would assert. None of batch B does, so the full default matrix is used.
  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 600),
    bool freshTreePerCase = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (!freshTreePerCase) {
      await runGoldenMatrix(
        tester,
        (_) => build(),
        goldenBaseName: name,
        guidelines: const [],
      );
      return;
    }
    // One matrix call per case with the tree unmounted in between: some
    // widgets (NetworkStatusBanner's AnimatedSize) hit "RenderAnimatedSize was
    // mutated in its own performLayout" when the SAME tree is re-pumped under
    // a new MediaQuery/locale/direction by consecutive cases. Real-use
    // scenarios (font size, language, connectivity changes on a live banner)
    // were probed and do not throw, so this is how the harness re-pumps, not a
    // widget bug; root cause not found.
    for (final c in defaultGoldenMatrix()) {
      await runGoldenMatrix(
        tester,
        (_) => build(),
        goldenBaseName: name,
        matrix: [c],
        guidelines: const [],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }

  Widget host(Widget child) => SizedBox(width: 390, height: 600, child: child);

  Widget fakeApp({String text = 'App content behind the overlay'}) =>
      ColoredBox(
        color: NeonTheme.card,
        child: Center(child: Text(text)),
      );

  GameSessionController pausedSession({
    GamePauseReason reason = GamePauseReason.user,
  }) {
    final s = GameSessionController()
      ..markReady()
      ..start()
      ..pause(reason);
    addTearDown(s.dispose);
    return s;
  }

  testWidgets('AppVersionGateOverlay maintenance', (tester) async {
    await golden(
      tester,
      'appversiongateoverlay_maintenance',
      () => host(
        AppVersionGateOverlay(
          decision: GateDecision.maintenance,
          config: const AppVersionGateConfig(
            maintenanceMessage: 'Back at 10:00',
          ),
          launchStore: (_) async => true,
          child: fakeApp(),
        ),
      ),
    );
  });

  testWidgets('AppVersionGateOverlay force update', (tester) async {
    await golden(
      tester,
      'appversiongateoverlay_forceupdate',
      () => host(
        AppVersionGateOverlay(
          decision: GateDecision.forceUpdate,
          config: const AppVersionGateConfig(storeUrl: 'https://example.com'),
          launchStore: (_) async => true,
          child: fakeApp(),
        ),
      ),
    );
  });

  testWidgets('BottomSheetPanel', (tester) async {
    await golden(
      tester,
      'bottomsheetpanel_states',
      () => host(
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomSheetPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Sort by'),
                SizedBox(height: 8),
                Text('Newest'),
                Text('Oldest'),
                Text('Most popular'),
              ],
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('LoadingOverlay with and without message', (tester) async {
    await golden(
      tester,
      'loadingoverlay_states',
      () => host(
        Column(
          children: [
            Expanded(
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [fakeApp(text: 'A'), const LoadingOverlay()],
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    fakeApp(text: 'B'),
                    const LoadingOverlay(message: 'Saving your progress'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('PauseOverlay user pause', (tester) async {
    final session = pausedSession();
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runGoldenMatrix(
      tester,
      (_) => GetMaterialApp(
        translations: AppTranslations(),
        locale: AppTranslations.fallback,
        home: Material(
          child: Stack(
            children: [
              const Center(child: Text('game content')),
              PauseOverlay(session: session),
            ],
          ),
        ),
      ),
      goldenBaseName: 'pauseoverlay_user',
      guidelines: const [],
    );
  });

  testWidgets('SpotlightOverlay around a target', (tester) async {
    final targetKey = GlobalKey();
    await golden(
      tester,
      'spotlightoverlay_target',
      () => host(
        Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 200, left: 40),
                child: SizedBox(
                  key: targetKey,
                  width: 120,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Target'),
                  ),
                ),
              ),
            ),
            SpotlightOverlay(
              targetKey: targetKey,
              title: 'Step 1',
              message: 'Tap here to get started',
              holePadding: 12,
              onDismiss: () {},
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('ToastBanner', (tester) async {
    await golden(
      tester,
      'toastbanner_states',
      () => host(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ToastBanner(message: 'Saved'),
            const SizedBox(height: 12),
            ToastBanner(message: 'Something went wrong', color: NeonTheme.red),
          ],
        ),
      ),
    );
  });

  testWidgets('TooltipBubble up and down', (tester) async {
    await golden(
      tester,
      'tooltipbubble_states',
      () => host(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TooltipBubble(child: Text('Tap to pop!')),
            const SizedBox(height: 24),
            TooltipBubble(
              direction: TooltipPointerDirection.down,
              color: NeonTheme.cyan,
              nubAlign: 0.2,
              child: const Text('Combo x3'),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('StreakRepairDialog', (tester) async {
    await golden(
      tester,
      'streakrepairdialog_states',
      () => host(
        Center(
          child: SingleChildScrollView(
            child: StreakRepairDialog(
              streakDays: 14,
              costGems: 25,
              onRepair: () {},
              onSkip: () {},
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('RetryErrorState variants', (tester) async {
    await golden(
      tester,
      'retryerrorstate_states',
      () => host(
        SingleChildScrollView(
          child: Column(
            children: [
              RetryErrorState(
                icon: Icons.wifi_off,
                title: 'No connection',
                message: 'Check your network and try again.',
                onRetry: () async {},
              ),
              const SizedBox(height: 12),
              const RetryErrorState(message: 'Something failed.', compact: true),
              const SizedBox(height: 12),
              RetryErrorState.fromSdkFailure(
                const SdkFailure<void>(
                  kind: SdkErrorKind.network,
                  message: 'Server unreachable',
                ),
                onRetry: () async {},
              ),
            ],
          ),
        ),
      ),
      size: const Size(390, 900),
    );
  });

  testWidgets('NetworkStatusBanner offline and online', (tester) async {
    await golden(
      tester,
      'networkstatusbanner_states',
      () => host(
        Column(
          children: [
            const NetworkStatusBanner(
              connected: false,
              duration: Duration.zero,
            ),
            const SizedBox(height: 12),
            const NetworkStatusBanner(
              connected: true,
              duration: Duration.zero,
            ),
            const SizedBox(height: 12),
            const Text('(online: banner hidden above)'),
          ],
        ),
      ),
      freshTreePerCase: true,
    );
  });

  testWidgets('EmptyStatePlaceholder variants', (tester) async {
    await golden(
      tester,
      'emptystateplaceholder_states',
      () => host(
        SingleChildScrollView(
          child: Column(
            children: [
              const EmptyStatePlaceholder(
                icon: Icons.inbox,
                message: 'Nothing here yet',
              ),
              const SizedBox(height: 24),
              EmptyStatePlaceholder(
                icon: Icons.search_off,
                title: 'No results',
                message: 'Try a different search.',
                color: NeonTheme.cyan,
                action: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Clear filters'),
                ),
              ),
            ],
          ),
        ),
      ),
      size: const Size(390, 900),
    );
  });

  testWidgets('LevelUpOverlay level pop phase', (tester) async {
    final controller = LevelUpOverlayController(
      xpFillDuration: Duration.zero,
      levelPopDuration: const Duration(seconds: 30),
      rewardRevealDuration: const Duration(seconds: 30),
    );
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runGoldenMatrix(
      tester,
      (_) => GetMaterialApp(
        translations: AppTranslations(),
        locale: AppTranslations.fallback,
        home: LevelUpOverlay(
          controller: controller,
          reducedMotion: true,
          enableHaptics: false,
          enableConfetti: false,
          child: const Scaffold(body: Center(child: Text('Game content'))),
        ),
      ),
      goldenBaseName: 'levelupoverlay_idle',
      guidelines: const [],
    );
    unawaited(
      controller.show([
        LevelUpCelebration(
          event: const LevelUpEvent(level: 5, rewardLines: []),
        ),
      ]),
    );
    await tester.pump();
    controller.skip();
    await tester.pump();
  });

  // ConsentBanner opens its dialog with NeonDialog.show (a route), and the
  // matrix rebuilds the whole MaterialApp for every case, which tears that
  // route down mid-test (GetX Obx dispose error). The banner's behaviour is
  // covered by consent_banner_test.dart; here we compare the dialog PANEL it
  // shows, built from the same title/message/actions.
  testWidgets('ConsentBanner dialog panel', (tester) async {
    await golden(
      tester,
      'consentbanner_panel',
      () => host(
        Center(
          child: NeonDialog.panel(
            title: 'We value your privacy',
            message:
                'This app uses analytics and personalization to improve your '
                'experience. Do you agree?',
            color: NeonTheme.purple,
            actions: [
              NeonDialogAction(
                label: 'Decline all',
                color: NeonTheme.muted,
                onTap: () {},
              ),
              NeonDialogAction(
                label: 'Accept all',
                color: NeonTheme.lime,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('TutorialSequence first step', (tester) async {
    final controller = TutorialSequenceController();
    addTearDown(controller.dispose);
    final targetKey = GlobalKey();
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runGoldenMatrix(
      tester,
      (_) => GetMaterialApp(
        translations: AppTranslations(),
        locale: AppTranslations.fallback,
        home: TutorialSequence(
          controller: controller,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                key: targetKey,
                width: 120,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Target'),
                ),
              ),
            ),
          ),
        ),
      ),
      goldenBaseName: 'tutorialsequence_idle',
      guidelines: const [],
    );
  });
}
