import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/presentation/widgets/common/battle_pass_road.dart';
import 'package:roy_casual_kit/presentation/widgets/common/coin_multiplier_wheel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/daily_login_calendar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/flash_sale_offer_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/mystery_chest_opening.dart';
import 'package:roy_casual_kit/presentation/widgets/common/piggy_bank_vault.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_choice_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_popup.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_sequence_coordinator.dart';
import 'package:roy_casual_kit/presentation/widgets/common/scratch_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/season_event_banner.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tiered_reward_chest.dart';
import 'package:roy_casual_kit/presentation/widgets/common/wheel_spinner.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

/// ENH-121 (batch D): reward / shop / event widgets. One golden per widget,
/// interesting states stacked in one frame, rendered through the shared
/// matrix. Deterministic: wheels are never spun, particles are off, countdown
/// widgets get a deadline built from `DateTime.now()` plus a margin large
/// enough that the rendered text cannot change between cases (hours/days
/// granularity for the banner; whole seconds for the flash sale, where the
/// widget itself ceils the remaining time).
///
/// Not covered on purpose: `AchievementUnlockListener` (renders only its
/// child; the toast it raises is covered by the `ToastBanner` golden in
/// batch B), spin/scratch/open/claim animations (behavior tests own those).
void main() {
  final previous = installGoldenTolerance(
    'batch_d_reward_widgets_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  Widget stack(List<Widget> children, {double width = 340}) => SizedBox(
    width: width,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 760),
    Future<void> Function(WidgetTester)? afterPump,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runGoldenMatrix(
      tester,
      (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(child: build()),
      ),
      goldenBaseName: name,
      guidelines: const [],
      afterPump: afterPump,
    );
  }

  testWidgets('RewardPopup', (tester) async {
    await golden(
      tester,
      'rewardpopup_states',
      () => SizedBox(
        width: 340,
        height: 560,
        child: RewardPopup(
          title: 'Level cleared!',
          message: '+250 coins',
          icon: Icons.emoji_events,
          enableParticles: false,
          onDismiss: () {},
        ),
      ),
      // Entrance is a spring: let it settle before the capture.
      afterPump: (t) => t.pump(const Duration(seconds: 2)),
    );
  });

  testWidgets('RewardChoicePanel', (tester) async {
    await golden(
      tester,
      'rewardchoicepanel_states',
      () => SizedBox(
        width: 340,
        child: RewardChoicePanel(
          onConfirm: (_) async {},
          claimedIds: const {'b'},
          options: const [
            RewardChoiceOption(
              id: 'a',
              label: 'Coin pack',
              icon: Icons.monetization_on,
              lines: [RewardLine(currency: 'coins', amount: 500)],
            ),
            RewardChoiceOption(
              id: 'b',
              label: 'Gem pack',
              icon: Icons.diamond,
              lines: [RewardLine(currency: 'gems', amount: 20)],
            ),
            RewardChoiceOption(
              id: 'c',
              label: 'VIP bundle',
              icon: Icons.workspace_premium,
              lines: [
                RewardLine(currency: 'coins', amount: 2000),
                RewardLine(currency: 'gems', amount: 100),
              ],
              locked: true,
              lockedReason: 'Reach level 10',
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('RewardChoicePanel empty', (tester) async {
    await golden(
      tester,
      'rewardchoicepanel_empty',
      () => SizedBox(
        width: 340,
        child: RewardChoicePanel(onConfirm: (_) async {}, options: const []),
      ),
    );
  });

  testWidgets('RewardSequenceCoordinator', (tester) async {
    final controller = RewardSequenceController()
      ..advanceTo(RewardSequenceStep.ready);
    addTearDown(controller.dispose);
    await golden(
      tester,
      'rewardsequencecoordinator_ready',
      () => SizedBox(
        width: 340,
        height: 420,
        child: RewardSequenceCoordinator(
          controller: controller,
          autoStart: false,
          banner: const Text('Victory'),
          content: const Icon(Icons.card_giftcard, size: 64),
          counter: const Text('+1,250'),
          actionButton: ElevatedButton(
            onPressed: () {},
            child: const Text('Collect'),
          ),
        ),
      ),
    );
  });

  testWidgets('TieredRewardChest', (tester) async {
    await golden(
      tester,
      'tieredrewardchest_tiers',
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tier in ChestTier.values)
            TieredRewardChest(
              currentTier: tier,
              onOpen: () {},
              size: const Size(150, 130),
            ),
          TieredRewardChest(
            currentTier: ChestTier.values.first,
            onOpen: () {},
            isOpened: true,
            size: const Size(150, 130),
          ),
        ],
      ),
    );
  });

  testWidgets('PiggyBankVault', (tester) async {
    await golden(
      tester,
      'piggybankvault_states',
      () => stack([
        PiggyBankVault(
          amount: 0,
          capacity: 1000,
          onBreak: () {},
          onUnlock: () {},
        ),
        PiggyBankVault(
          amount: 420,
          capacity: 1000,
          onBreak: () {},
          onUnlock: () {},
        ),
        PiggyBankVault(
          amount: 1000,
          capacity: 1000,
          onBreak: () {},
          onUnlock: () {},
          animateWhenFull: false,
        ),
        PiggyBankVault(
          amount: 600,
          capacity: 1000,
          isUnlocked: false,
          onBreak: () {},
          onUnlock: () {},
        ),
      ]),
    );
  });

  testWidgets('MysteryChestOpening', (tester) async {
    await golden(
      tester,
      'mysterychestopening_idle',
      () => MysteryChestOpening(reward: const Text('Prize')),
    );
  });

  testWidgets('BattlePassRoad', (tester) async {
    await golden(
      tester,
      'battlepassroad_states',
      () => SizedBox(
        width: 340,
        child: BattlePassRoad(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          progress: 250,
          vipEnabled: true,
          claimedFreeIds: const {'m1'},
          claimedVipIds: const {},
          onClaimMilestone: (_, _) {},
          milestones: [
            BattlePassMilestone(
              id: 'm1',
              requiredProgress: 100,
              freeRewards: const [RewardLine(currency: 'coins', amount: 100)],
              vipRewards: const [RewardLine(currency: 'gems', amount: 5)],
            ),
            BattlePassMilestone(
              id: 'm2',
              requiredProgress: 200,
              freeRewards: const [RewardLine(currency: 'coins', amount: 250)],
              vipRewards: const [RewardLine(currency: 'gems', amount: 10)],
            ),
            BattlePassMilestone(
              id: 'm3',
              requiredProgress: 400,
              freeRewards: const [RewardLine(currency: 'coins', amount: 500)],
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('FlashSaleOfferCard', (tester) async {
    await golden(
      tester,
      'flashsaleoffercard_states',
      () => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FlashSaleOfferCard(
            width: 280,
            title: 'Starter pack',
            subtitle: 'Best value',
            priceLabel: '\$0.99',
            originalPriceLabel: '\$4.99',
            discountPercent: 80,
            expiresAt: DateTime.now().add(
              const Duration(hours: 5, minutes: 30, seconds: 30),
            ),
            onBuyTap: () {},
          ),
          FlashSaleOfferCard(
            width: 280,
            title: 'Gem stash',
            priceLabel: '\$1.99',
            discountPercent: 50,
            expiresAt: DateTime.now().add(const Duration(minutes: 12)),
            onBuyTap: () {},
            loading: true,
          ),
          FlashSaleOfferCard(
            width: 280,
            title: 'Gone',
            priceLabel: '\$2.99',
            discountPercent: 30,
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
            onBuyTap: () {},
          ),
        ],
      ),
    );
  });

  testWidgets('SeasonEventBanner', (tester) async {
    await golden(
      tester,
      'seasoneventbanner_states',
      () => stack([
        SeasonEventBanner(
          title: 'Winter Festival',
          subtitle: 'Collect snowflakes',
          milestoneLabel: 'Chest',
          endsAt: DateTime.now().add(
            const Duration(days: 3, hours: 4, minutes: 30),
          ),
          progress: 0.4,
          onTap: () {},
          width: 320,
        ),
        SeasonEventBanner(
          title: 'Spring Bloom',
          endsAt: DateTime.now().add(const Duration(hours: 2, minutes: 30)),
          progress: 1,
          width: 320,
        ),
        SeasonEventBanner(
          title: 'Autumn Rush',
          endsAt: DateTime.now().subtract(const Duration(days: 1)),
          progress: 0.7,
          width: 320,
        ),
      ]),
    );
  });

  testWidgets('DailyLoginCalendarWidget', (tester) async {
    await golden(
      tester,
      'dailylogincalendar_states',
      () => stack([
        DailyLoginCalendarWidget(
          currentStreakDay: 2,
          claimedDaysInCycle: const {1, 2},
          canClaimToday: true,
          onClaim: () {},
        ),
        DailyLoginCalendarWidget(
          currentStreakDay: 4,
          claimedDaysInCycle: const {1, 2, 3, 4},
          canClaimToday: false,
          onClaim: () {},
        ),
        DailyLoginCalendarWidget(
          currentStreakDay: 0,
          claimedDaysInCycle: const {},
          canClaimToday: true,
          claiming: true,
          onClaim: () {},
        ),
      ]),
    );
  });

  testWidgets('ScratchCard', (tester) async {
    Widget card() => ScratchCard(
      size: const Size(240, 140),
      prize: const Center(child: Text('500 coins')),
      cover: Container(color: Colors.grey),
      threshold: 0.95,
    );
    await golden(tester, 'scratchcard_covered', card);
    await golden(
      tester,
      'scratchcard_scratched',
      card,
      afterPump: (t) async {
        final gesture = await t.startGesture(
          t.getTopLeft(find.byType(ScratchCard)) + const Offset(20, 40),
        );
        await gesture.moveBy(const Offset(120, 0));
        await gesture.moveBy(const Offset(0, 40));
        await gesture.moveBy(const Offset(-100, 0));
        await gesture.up();
        await t.pump();
      },
    );
  });

  testWidgets('WheelSpinner', (tester) async {
    final controller = WheelSpinnerController();
    addTearDown(controller.dispose);
    await golden(
      tester,
      'wheelspinner_idle',
      () => WheelSpinner(
        size: 240,
        controller: controller,
        backgroundColor: NeonTheme.card,
        onSpinEnd: (_) {},
        segments: const [
          WheelSegment(label: '10', color: Color(0xFFE53935)),
          WheelSegment(label: '50', color: Color(0xFF1E88E5)),
          WheelSegment(label: '100', color: Color(0xFF43A047)),
          WheelSegment(label: '500', color: Color(0xFFFDD835)),
          WheelSegment(label: '5', color: Color(0xFF8E24AA)),
          WheelSegment(label: '20', color: Color(0xFFFB8C00)),
        ],
      ),
    );
  });

  testWidgets('CoinMultiplierWheel', (tester) async {
    final controller = CoinMultiplierWheelController();
    addTearDown(controller.dispose);
    await golden(
      tester,
      'coinmultiplierwheel_idle',
      () => CoinMultiplierWheel(
        radius: 110,
        autoStart: false,
        controller: controller,
        backgroundColor: NeonTheme.card,
      ),
    );
  });
}
