import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _milestones = [
  StreakMilestone(days: 3, rewardLabel: '50 coins'),
  StreakMilestone(days: 7, rewardLabel: 'Mystery chest'),
  StreakMilestone(days: 14, rewardLabel: 'Rare skin'),
  StreakMilestone(days: 30, rewardLabel: 'Legendary hero'),
];

Widget subject({
  List<StreakMilestone> milestones = _milestones,
  int streak = 0,
  Set<int> claimed = const {},
  ValueChanged<int>? onClaim,
  Duration guard = const Duration(milliseconds: 400),
  double scale = 1,
  bool reducedMotion = false,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reducedMotion,
    ),
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: StreakMilestoneStrip(
            milestones: milestones,
            currentStreak: streak,
            claimedDays: claimed,
            onClaim: onClaim ?? (_) {},
            guardWindow: guard,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates milestones, streak, claimed days, labels and guard', () {
    StreakMilestoneStrip make({
      List<StreakMilestone> milestones = _milestones,
      int streak = 0,
      Set<int> claimed = const {},
      String claim = 'Claim',
      Duration guard = Duration.zero,
    }) => StreakMilestoneStrip(
      milestones: milestones,
      currentStreak: streak,
      claimedDays: claimed,
      claimLabel: claim,
      guardWindow: guard,
      onClaim: (_) {},
    );

    expect(() => make(milestones: const []), throwsArgumentError);
    expect(
      () =>
          make(milestones: const [StreakMilestone(days: 0, rewardLabel: 'x')]),
      throwsArgumentError,
    );
    expect(
      () => make(
        milestones: const [
          StreakMilestone(days: 7, rewardLabel: 'a'),
          StreakMilestone(days: 7, rewardLabel: 'b'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        milestones: const [
          StreakMilestone(days: 7, rewardLabel: 'a'),
          StreakMilestone(days: 3, rewardLabel: 'b'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          make(milestones: const [StreakMilestone(days: 3, rewardLabel: ' ')]),
      throwsArgumentError,
    );
    expect(() => make(streak: -1), throwsArgumentError);
    expect(() => make(claimed: {5}), throwsArgumentError);
    expect(() => make(claim: ' '), throwsArgumentError);
    expect(
      () => make(guard: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
    expect(() => make(claimed: {3, 7}), returnsNormally);
  });

  testWidgets('no milestone reached: all locked, none claimable', (
    tester,
  ) async {
    await tester.pumpWidget(subject(streak: 1));
    expect(find.text('Locked'), findsWidgets);
    expect(find.byKey(const ValueKey('streakClaim_3')), findsNothing);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('50 coins'), findsOneWidget);
  });

  testWidgets('reached but unclaimed shows Claim and routes the day', (
    tester,
  ) async {
    final claimed = <int>[];
    await tester.pumpWidget(subject(streak: 8, onClaim: claimed.add));
    expect(find.byKey(const ValueKey('streakClaim_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('streakClaim_7')), findsOneWidget);
    expect(find.byKey(const ValueKey('streakClaim_14')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('streakClaim_7')));
    expect(claimed, [7]);
  });

  testWidgets('claimed milestones show state and are not tappable', (
    tester,
  ) async {
    final claimed = <int>[];
    await tester.pumpWidget(
      subject(streak: 8, claimed: {3}, onClaim: claimed.add),
    );
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.byKey(const ValueKey('streakClaim_3')), findsNothing);
    expect(find.byKey(const ValueKey('streakClaim_7')), findsOneWidget);
  });

  testWidgets('claimed milestone above a reset streak stays claimed', (
    tester,
  ) async {
    await tester.pumpWidget(subject(streak: 0, claimed: {14}));
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.byKey(const ValueKey('streakClaim_14')), findsNothing);
  });

  testWidgets(
    'rapid double tap on one milestone fires once, others unaffected',
    (tester) async {
      final claimed = <int>[];
      await tester.pumpWidget(subject(streak: 8, onClaim: claimed.add));
      await tester.tap(find.byKey(const ValueKey('streakClaim_3')));
      await tester.tap(find.byKey(const ValueKey('streakClaim_3')));
      await tester.tap(find.byKey(const ValueKey('streakClaim_7')));
      expect(claimed, [3, 7]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.tap(find.byKey(const ValueKey('streakClaim_3')));
      expect(claimed, [3, 7, 3]);
    },
  );

  testWidgets('claim target is at least 48dp', (tester) async {
    await tester.pumpWidget(subject(streak: 8));
    final size = tester.getSize(find.byKey(const ValueKey('streakClaim_3')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('many milestones build lazily and scroll horizontally', (
    tester,
  ) async {
    final many = [
      for (var i = 1; i <= 60; i++)
        StreakMilestone(days: i * 5, rewardLabel: 'Reward $i'),
    ];
    await tester.pumpWidget(subject(milestones: many, streak: 400));
    expect(find.byKey(const ValueKey('streakMilestone_5')), findsOneWidget);
    expect(find.byKey(const ValueKey('streakMilestone_300')), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('streakMilestoneList')),
      const Offset(-3000, 0),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('streakMilestone_5')), findsNothing);
  });

  testWidgets('semantics describe each milestone and its claim action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(subject(streak: 8, claimed: {3}));
      String labelOf(int days) => tester
          .getSemantics(find.byKey(ValueKey('streakMilestone_$days')))
          .label;
      expect(labelOf(3), '3 days, 50 coins, Claimed');
      expect(labelOf(14), '14 days, Rare skin, Locked');
      // A claimable card merges its Claim button's label into the card node.
      expect(labelOf(7), contains('7 days, Mystery chest, Claim'));
      expect(labelOf(7), contains('Claim 7 days'));
      final claimNode = tester.getSemantics(
        find.byKey(const ValueKey('streakClaim_7')),
      );
      expect(claimNode.label, contains('Claim 7 days'));
      expect(
        claimNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      // Locked and claimed milestones expose no tap action.
      for (final days in [3, 14]) {
        final node = tester.getSemantics(
          find.byKey(ValueKey('streakMilestone_$days')),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp, 2x text and RTL do not overflow or clip the action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(streak: 8, scale: 2, direction: TextDirection.rtl),
    );
    expect(
      Directionality.of(tester.element(find.byType(StreakMilestoneStrip))),
      TextDirection.rtl,
    );
    final tile = tester.getRect(
      find.byKey(const ValueKey('streakMilestone_3')),
    );
    final action = tester.getRect(find.byKey(const ValueKey('streakClaim_3')));
    expect(tile.contains(action.center), isTrue);
    expect(action.bottom, lessThanOrEqualTo(tile.bottom + 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('streak change mid-scroll keeps position and fires no callback', (
    tester,
  ) async {
    final many = [
      for (var i = 1; i <= 40; i++)
        StreakMilestone(days: i * 3, rewardLabel: 'Reward $i'),
    ];
    final claimed = <int>[];
    await tester.pumpWidget(
      subject(milestones: many, streak: 10, onClaim: claimed.add),
    );
    final list = find.byKey(const ValueKey('streakMilestoneList'));
    await tester.drag(list, const Offset(-600, 0));
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    final before = scrollable.position.pixels;
    await tester.pumpWidget(
      subject(milestones: many, streak: 13, onClaim: claimed.add),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(scrollable.position.pixels, before);
    expect(claimed, isEmpty);
  });

  testWidgets(
    'newly reached milestone pulses once; mount and reduced motion do not',
    (tester) async {
      await tester.pumpWidget(subject(streak: 8));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(subject(streak: 14));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(subject(streak: 0, reducedMotion: true));
      await tester.pumpWidget(subject(streak: 30, reducedMotion: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('unmount mid-pulse disposes the controller without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(subject(streak: 2));
    await tester.pumpWidget(subject(streak: 8));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
