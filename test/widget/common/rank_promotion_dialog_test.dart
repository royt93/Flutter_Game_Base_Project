import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

final _rewards = [
  MilestoneReward(
    icon: Icons.diamond_rounded,
    label: 'Gems',
    amountLabel: 'x100',
  ),
  MilestoneReward(
    icon: Icons.favorite_rounded,
    label: 'Lives',
    amountLabel: 'x5',
  ),
];

Widget _subject({
  LeaderboardTier fromTier = LeaderboardTier.bronze,
  LeaderboardTier toTier = LeaderboardTier.silver,
  VoidCallback? onContinue,
  VoidCallback? onShare,
  List<MilestoneReward>? rewards,
  bool disableAnimations = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: RankPromotionDialog(
          fromTier: fromTier,
          toTier: toTier,
          onContinue: onContinue ?? () {},
          onShare: onShare,
          rewards: rewards ?? _rewards,
        ),
      ),
    ),
  ),
);

void main() {
  group('RankPromotionDialog validation', () {
    test('rejects non-promotion tier pairs', () {
      for (final pair in [
        (LeaderboardTier.silver, LeaderboardTier.silver),
        (LeaderboardTier.gold, LeaderboardTier.bronze),
      ]) {
        expect(
          () => RankPromotionDialog(
            fromTier: pair.$1,
            toTier: pair.$2,
            onContinue: () {},
          ),
          throwsArgumentError,
        );
      }
    });

    test('rejects empty title and labels', () {
      expect(
        () => RankPromotionDialog(
          fromTier: LeaderboardTier.bronze,
          toTier: LeaderboardTier.silver,
          onContinue: () {},
          title: ' ',
        ),
        throwsArgumentError,
      );
      expect(
        () => RankPromotionDialog(
          fromTier: LeaderboardTier.bronze,
          toTier: LeaderboardTier.silver,
          onContinue: () {},
          continueLabel: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => RankPromotionDialog(
          fromTier: LeaderboardTier.bronze,
          toTier: LeaderboardTier.silver,
          onContinue: () {},
          shareLabel: ' ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('RankPromotionDialog UI', () {
    testWidgets('shows tier transition, rewards and rays', (tester) async {
      await tester.pumpWidget(
        _subject(
          fromTier: LeaderboardTier.gold,
          toTier: LeaderboardTier.diamond,
        ),
      );

      expect(find.text('Gold'), findsOneWidget);
      expect(find.text('Diamond'), findsOneWidget);
      expect(find.text('DIAMOND'), findsOneWidget);
      expect(find.text('Gems'), findsOneWidget);
      expect(find.text('x100'), findsOneWidget);
      expect(find.byKey(const ValueKey('rankPromotionRays')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides reward section when there are no rewards', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(rewards: const []));
      expect(find.text('Promotion Rewards'), findsNothing);
    });

    testWidgets('semantics reads promotion and rewards', (tester) async {
      await tester.pumpWidget(_subject());
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('rankPromotionSemantics')),
      );
      expect(semantics.properties.label, contains('Bronze to Silver'));
      expect(semantics.properties.label, contains('Gems x100'));
    });

    testWidgets('reduced motion keeps rays static without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(disableAnimations: true));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('rankPromotionRays')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('static .show routes Continue and Share to caller', (
      tester,
    ) async {
      var continued = 0;
      var shared = 0;

      Future<void> open() async {
        await tester.tap(find.text('Open'));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => RankPromotionDialog.show(
                  context,
                  fromTier: LeaderboardTier.silver,
                  toTier: LeaderboardTier.gold,
                  rewards: _rewards,
                  onContinue: () => continued++,
                  onShare: () => shared++,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await open();
      expect(find.text('Rank Promoted!'), findsOneWidget);
      tester
          .widget<NeonDialogButton>(
            find.byWidgetPredicate(
              (w) => w is NeonDialogButton && w.action.label == 'Share',
            ),
          )
          .action
          .onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(shared, 1);
      expect(continued, 0);

      await open();
      tester
          .widget<NeonDialogButton>(
            find.byWidgetPredicate(
              (w) => w is NeonDialogButton && w.action.label == 'Continue',
            ),
          )
          .action
          .onTap();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(continued, 1);
      expect(shared, 1);
    });

    testWidgets('.show hides Share when onShare is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => RankPromotionDialog.show(
                  context,
                  fromTier: LeaderboardTier.bronze,
                  toTier: LeaderboardTier.silver,
                  onContinue: () {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Share',
        ),
        findsNothing,
      );
    });

    testWidgets('unmount mid-entrance disposes rays controller cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => RankPromotionDialog.show(
                  context,
                  fromTier: LeaderboardTier.bronze,
                  toTier: LeaderboardTier.silver,
                  onContinue: () {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
