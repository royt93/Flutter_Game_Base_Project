import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/milestone_celebration_dialog.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

List<MilestoneReward> _sampleRewards() => [
  MilestoneReward(
    icon: Icons.monetization_on_rounded,
    label: 'Coins',
    amountLabel: '+500',
  ),
  MilestoneReward(
    icon: Icons.flash_on_rounded,
    label: 'Hammer Booster',
    amountLabel: 'x2',
  ),
  MilestoneReward(icon: Icons.face_rounded, label: 'Golden Avatar Frame'),
];

void main() {
  group('MilestoneReward and Dialog validation', () {
    test('rejects empty label', () {
      expect(
        () => MilestoneReward(icon: Icons.star, label: ''),
        throwsArgumentError,
      );
      expect(
        () => MilestoneReward(icon: Icons.star, label: '   '),
        throwsArgumentError,
      );
    });

    test('rejects level < 1 or empty rewards', () {
      expect(
        () => MilestoneCelebrationDialog(
          level: 0,
          rewards: _sampleRewards(),
          onClaim: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => MilestoneCelebrationDialog(
          level: 25,
          rewards: const [],
          onClaim: () {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('MilestoneCelebrationDialog panel rendering', () {
    testWidgets('renders level number, all reward labels, and claim button', (
      tester,
    ) async {
      var claimed = false;
      await tester.pumpWidget(
        _wrap(
          MilestoneCelebrationDialog(
            level: 50,
            subtitle: 'You completed 50 levels!',
            rewards: _sampleRewards(),
            onClaim: () => claimed = true,
          ),
        ),
      );

      expect(find.text('50'), findsOneWidget);
      expect(find.text('Milestone Reached!'), findsOneWidget);
      expect(find.text('You completed 50 levels!'), findsOneWidget);
      expect(find.text('Coins'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('Hammer Booster'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(find.text('Golden Avatar Frame'), findsOneWidget);

      await tester.tap(find.text('Claim'));
      expect(claimed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduced Motion disables ray sweep ticker', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MilestoneCelebrationDialog(
            level: 100,
            rewards: _sampleRewards(),
            onClaim: () {},
          ),
          reduced: true,
        ),
      );

      final rayFinder = find.byKey(const ValueKey('milestoneRays'));
      expect(rayFinder, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics announce level and all rewards', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          MilestoneCelebrationDialog(
            level: 25,
            rewards: _sampleRewards(),
            onClaim: () {},
          ),
        ),
      );

      final node = tester.getSemantics(
        find.byKey(const ValueKey('milestoneSemantics')),
      );
      expect(node.label, contains('Level 25 milestone'));
      expect(node.label, contains('Coins +500'));
      expect(node.label, contains('Hammer Booster x2'));
      expect(node.label, contains('Golden Avatar Frame'));
      handle.dispose();
    });
  });

  group('MilestoneCelebrationDialog.show', () {
    testWidgets('opens via overlay and claim button calls callback', (
      tester,
    ) async {
      var claimed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const ValueKey('openBtn'),
                onPressed: () => MilestoneCelebrationDialog.show(
                  context,
                  level: 50,
                  rewards: _sampleRewards(),
                  onClaim: () => claimed = true,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('openBtn')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Milestone Reached!'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);

      final claimButton = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Claim',
        ),
      );
      claimButton.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      expect(claimed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
