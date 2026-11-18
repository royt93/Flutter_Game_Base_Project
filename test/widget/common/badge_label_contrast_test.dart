import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/utils/theme_contrast_validator.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/contrast_audit.dart';

// BUG-132: labels on solid accent badges must reach AA while the fill is kept.
void main() {
  tearDown(() => NeonTheme.dark = false);

  final cases = <String, Widget Function()>{
    'ClanChatPreviewBar': () =>
        ClanChatPreviewBar(onTap: () {}, unreadCount: 3),
    'QuestProgressPill': () => QuestProgressPill(
      completed: 2,
      total: 3,
      claimableCount: 1,
      onTap: () {},
    ),
    'IconBadgeButton default': () =>
        IconBadgeButton(icon: Icons.mail, onTap: () {}, badgeCount: 3),
    'IconBadgeButton dark badge': () => IconBadgeButton(
      icon: Icons.mail,
      onTap: () {},
      badgeCount: 3,
      badgeColor: const Color(0xFF222244),
    ),
    'ComebackBundleCard': () => ComebackBundleCard(
      title: 'Welcome',
      body: 'Welcome back',
      absenceLabel: '2 days',
      rewards: [MilestoneReward(icon: Icons.star, label: 'Coins')],
      onClaim: () {},
      badgeLabel: 'SPECIAL',
    ),
    'DailyOfferStack': () => DailyOfferStack(
      offers: const [
        DailyOffer(
          id: 'one',
          title: 'Offer',
          priceLabel: '10',
          badgeLabel: 'HOT',
        ),
      ],
      onOpen: (_) {},
    ),
    'MilestoneCelebrationDialog': () => MilestoneCelebrationDialog(
      level: 25,
      rewards: [MilestoneReward(icon: Icons.star, label: 'Reward')],
      onClaim: () {},
    ),
  };

  for (final dark in [false, true]) {
    for (final entry in cases.entries) {
      testWidgets('dark=$dark ${entry.key}: badge text has no AA finding', (
        tester,
      ) async {
        NeonTheme.dark = dark;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: NeonTheme.card,
              body: SingleChildScrollView(child: entry.value()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        final badge =
            auditRenderedTextContrast(
              tester,
              find.byType(Scaffold),
              defaultBackground: NeonTheme.card,
            ).where(
              (i) =>
                  i.foreground == Colors.white || i.foreground == Colors.black,
            );
        expect(badge, isEmpty, reason: '$badge');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('SegmentedTabBar selected label contrasts with its pill color', (
    tester,
  ) async {
    for (final color in [NeonTheme.cyan, NeonTheme.gold, NeonTheme.purple]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentedTabBar(
              labels: const ['First', 'Second'],
              selectedIndex: 0,
              onChanged: (_) {},
              activeColor: color,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final text = tester.widget<Text>(find.text('First'));
      expect(
        contrastRatio(text.style!.color!, color),
        greaterThanOrEqualTo(4.5),
        reason: 'active pill $color',
      );
    }
  });
}
