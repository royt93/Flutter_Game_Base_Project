import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _milestones = [
  GuildContributionMilestone(
    id: 'goal_100',
    requiredContribution: 100,
    reward: MilestoneReward(
      icon: Icons.diamond_rounded,
      label: 'Gems',
      amountLabel: 'x50',
    ),
  ),
  GuildContributionMilestone(
    id: 'goal_500',
    requiredContribution: 500,
    reward: MilestoneReward(
      icon: Icons.shield_rounded,
      label: 'Shield',
      amountLabel: 'x2',
    ),
  ),
];

Widget _subject({
  int total = 250,
  int goal = 1000,
  int personal = 25,
  List<GuildContributionMilestone>? milestones,
  VoidCallback? onContribute,
  ValueChanged<String>? onClaim,
  bool loading = false,
  String? errorMessage,
  Future<void> Function()? onRetry,
  bool textScale2 = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale2 ? 2 : 1)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: GuildContributionCard(
          guildName: 'Star Seekers',
          goalTitle: 'Community Boss',
          totalContribution: total,
          goalContribution: goal,
          memberContribution: personal,
          milestones: milestones ?? _milestones,
          onContribute: onContribute ?? () {},
          onClaimMilestone: onClaim ?? (_) {},
          isLoading: loading,
          errorMessage: errorMessage,
          onRetry: onRetry,
        ),
      ),
    ),
  ),
);

void main() {
  group('GuildContributionCard validation', () {
    test('rejects invalid contribution and milestone data', () {
      expect(
        () => GuildContributionCard(
          guildName: 'Guild',
          goalTitle: 'Goal',
          totalContribution: -1,
          goalContribution: 100,
          memberContribution: 0,
          milestones: const [],
          onContribute: () {},
          onClaimMilestone: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => GuildContributionCard(
          guildName: 'Guild',
          goalTitle: 'Goal',
          totalContribution: 0,
          goalContribution: 0,
          memberContribution: 0,
          milestones: const [],
          onContribute: () {},
          onClaimMilestone: (_) {},
        ),
        throwsArgumentError,
      );
      expect(
        () => GuildContributionCard(
          guildName: 'Guild',
          goalTitle: 'Goal',
          totalContribution: 0,
          goalContribution: 100,
          memberContribution: 0,
          milestones: [_milestones[1], _milestones[0]],
          onContribute: () {},
          onClaimMilestone: (_) {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('GuildContributionCard UI', () {
    testWidgets('shows guild, total and personal progress', (tester) async {
      await tester.pumpWidget(_subject());
      expect(find.text('Star Seekers'), findsOneWidget);
      expect(find.text('Community Boss'), findsOneWidget);
      expect(find.text('250 / 1,000'), findsOneWidget);
      expect(find.text('You: 25'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.25,
      );
    });

    testWidgets('contribute and reached milestone callbacks work', (
      tester,
    ) async {
      var contributed = 0;
      final claimed = <String>[];
      await tester.pumpWidget(
        _subject(
          total: 250,
          onContribute: () => contributed++,
          onClaim: claimed.add,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('guildContributeBtn')));
      await tester.tap(find.byKey(const ValueKey('guildMilestone_goal_100')));
      await tester.pump();
      expect(contributed, 1);
      expect(claimed, ['goal_100']);
      expect(
        find.byKey(const ValueKey('guildMilestone_goal_500')),
        findsOneWidget,
      );
    });

    testWidgets('loading and error/retry states replace content', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('guildContributeBtn')), findsNothing);

      var retried = false;
      await tester.pumpWidget(
        _subject(errorMessage: 'Offline', onRetry: () async => retried = true),
      );
      expect(find.text('Offline'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('guildContributionRetry')));
      expect(retried, isTrue);
    });

    testWidgets('semantics and text scale 2.0', (tester) async {
      await tester.pumpWidget(_subject(textScale2: true));
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('guildContributionSemantics')),
      );
      expect(semantics.properties.label, contains('Star Seekers'));
      expect(semantics.properties.label, contains('250 of 1,000 contribution'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('clamps progress at completed goal', (tester) async {
      await tester.pumpWidget(_subject(total: 1200, goal: 1000));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
    });
  });
}
