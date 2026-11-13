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

    testWidgets('GameOverCardTemplate', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: GameOverCardTemplate(
            title: 'Game Over',
            message: 'Better luck next time',
            statLines: const ['Score 12,340', 'Best 20,000', 'Combo x7'],
            primaryActionLabel: 'Retry',
            onPrimaryAction: () {},
            secondaryActionLabel: 'Home',
            onSecondaryAction: () {},
          ),
        ),
        targetFinder: find.byType(GameOverCardTemplate),
      );
    });

    testWidgets('VictoryCardTemplate', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: VictoryCardTemplate(
            title: 'Level Complete',
            statLines: const ['Score 12,340', 'Moves 18'],
            starsEarned: 3,
          ),
        ),
        targetFinder: find.byType(VictoryCardTemplate),
      );
    });

    testWidgets('StreakShieldCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: StreakShieldCard(
            streakDays: 14,
            shieldCount: 2,
            onUseShield: () {},
            onRepair: () {},
            onDismiss: () {},
          ),
        ),
        targetFinder: find.byType(StreakShieldCard),
      );
    });

    testWidgets('MilestoneCelebrationDialog', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: MilestoneCelebrationDialog(
            level: 50,
            rewards: [
              MilestoneReward(
                icon: Icons.diamond_rounded,
                label: 'Gems',
                amountLabel: '+100',
              ),
              MilestoneReward(icon: Icons.bolt_rounded, label: 'Energy'),
            ],
            onClaim: () {},
          ),
        ),
        targetFinder: find.byType(MilestoneCelebrationDialog),
      );
    });

    testWidgets('CloudSaveStatusCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: CloudSaveStatusCard(status: CloudSaveStatus.error),
        ),
        targetFinder: find.byType(CloudSaveStatusCard),
      );
    });

    testWidgets('ConnectivityStatusCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: ConnectivityStatusCard(
            state: ConnectivityCardState.degraded,
            queuedCount: 12,
          ),
        ),
        targetFinder: find.byType(ConnectivityStatusCard),
      );
    });

    testWidgets('OutboxQueueStatusCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: OutboxQueueStatusCard(
            pendingCount: 12,
            manualReviewCount: 3,
            status: OutboxQueueStatus.draining,
          ),
        ),
        targetFinder: find.byType(OutboxQueueStatusCard),
      );
    });

    testWidgets('AnnouncementPreviewCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: AnnouncementPreviewCard(
            messageText: 'Maintenance tonight from 02:00 to 04:00 UTC',
            localeLabel: 'English',
          ),
        ),
        targetFinder: find.byType(AnnouncementPreviewCard),
      );
    });

    testWidgets('FlashSaleOfferCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: FlashSaleOfferCard(
            title: 'Starter pack',
            priceLabel: '\$1.99',
            discountPercent: 60,
            expiresAt: DateTime.now().add(const Duration(hours: 5)),
            onBuyTap: () {},
          ),
        ),
        targetFinder: find.byType(FlashSaleOfferCard),
      );
    });

    testWidgets('ComebackBundleCard', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: ComebackBundleCard(
            title: 'Welcome back!',
            body: 'We saved a gift for you while you were away.',
            absenceLabel: '7 days away',
            rewards: [
              MilestoneReward(
                icon: Icons.diamond_rounded,
                label: 'Gems',
                amountLabel: '+100',
              ),
            ],
            onClaim: () {},
          ),
        ),
        targetFinder: find.byType(ComebackBundleCard),
      );
    });

    testWidgets('RankPromotionDialog', (tester) async {
      await runViewportSweep(
        tester,
        () => SingleChildScrollView(
          child: RankPromotionDialog(
            fromTier: LeaderboardTier.silver,
            toTier: LeaderboardTier.gold,
            onContinue: () {},
          ),
        ),
        targetFinder: find.byType(RankPromotionDialog),
      );
    });

    // 2.0x text is the harshest common accessibility setting: every widget
    // that fits at 1.0x must still not overflow at 320dp.
    group('2.0x text scale at 320dp and landscape', () {
      const tight = [
        ViewportCase('320x480', Size(320, 480)),
        ViewportCase('568x320-landscape', Size(568, 320)),
      ];
      final cases = <String, Widget Function()>{
        'CloudSaveStatusCard': () =>
            CloudSaveStatusCard(status: CloudSaveStatus.error),
        'ConnectivityStatusCard': () => ConnectivityStatusCard(
          state: ConnectivityCardState.degraded,
          queuedCount: 12,
        ),
        'OutboxQueueStatusCard': () => OutboxQueueStatusCard(
          pendingCount: 12,
          manualReviewCount: 3,
          status: OutboxQueueStatus.draining,
        ),
        'AnnouncementPreviewCard': () => AnnouncementPreviewCard(
          messageText: 'Maintenance tonight from 02:00 to 04:00 UTC',
          localeLabel: 'English',
        ),
        'GameOverCardTemplate': () => GameOverCardTemplate(
          title: 'Game Over',
          statLines: const ['Score 12,340', 'Best 20,000'],
          primaryActionLabel: 'Retry',
          onPrimaryAction: () {},
          secondaryActionLabel: 'Home',
          onSecondaryAction: () {},
        ),
        'StreakShieldCard': () => StreakShieldCard(
          streakDays: 14,
          shieldCount: 2,
          onUseShield: () {},
          onRepair: () {},
          onDismiss: () {},
        ),
      };
      for (final e in cases.entries) {
        testWidgets(e.key, (tester) async {
          await runViewportSweep(
            tester,
            () => SingleChildScrollView(child: e.value()),
            viewports: tight,
            textScale: 2.0,
          );
        });
      }
    });
  });
}
