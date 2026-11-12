import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/viewport_sweep.dart';

/// FEAT-200 pha 1: each entry is a widget that must survive every default
/// viewport. Add new widgets here; unsupported ones need a reason in
/// [_allowlist].
void main() {
  group('FEAT-200: viewport sweep', () {
    testWidgets('StreakRepairDialog', (tester) async {
      await runViewportSweep(
        tester,
        () =>
            StreakRepairDialog(streakDays: 14, onRepair: () {}, onSkip: () {}),
        targetFinder: find.byKey(const ValueKey('streakPanel')),
      );
    });

    testWidgets('StreakRepairDialog at 2.0x text', (tester) async {
      await runViewportSweep(
        tester,
        () =>
            StreakRepairDialog(streakDays: 14, onRepair: () {}, onSkip: () {}),
        targetFinder: find.byKey(const ValueKey('streakPanel')),
        textScale: 2.0,
      );
    });

    testWidgets('PrestigeConfirmationCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: PrestigeConfirmationCard(
            currentLevel: 50,
            requiredPrestigeValue: 'Level 50',
            currentMultiplier: 1.0,
            nextMultiplier: 1.5,
            rewards: const [
              PrestigeReward(
                icon: Icons.flash_on_rounded,
                label: 'Permanent Speed',
                amount: '+25%',
              ),
            ],
            onConfirm: () {},
            onCancel: () {},
          ),
        ),
        targetFinder: find.byType(PrestigeConfirmationCard),
      );
    });

    testWidgets('RewardPopup', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: RewardPopup(
            title: 'Daily reward',
            message: 'You earned 100 gems',
            icon: Icons.diamond_rounded,
            enableParticles: false,
            onDismiss: () {},
          ),
        ),
        targetFinder: find.byType(RewardPopup),
      );
    });

    testWidgets('SupportDiagnosticsCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: SupportDiagnosticsCard(
            summary: SupportDiagnosticsSummary(
              appVersion: '1.2.3',
              generatedAtText: '10:30 UTC',
              sections: const ['health', 'logs'],
            ),
            onShare: () async {},
          ),
        ),
        targetFinder: find.byType(SupportDiagnosticsCard),
      );
    });
  });
}
