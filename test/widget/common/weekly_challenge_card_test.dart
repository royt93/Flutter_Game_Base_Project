import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/weekly_challenge_card.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

List<ChallengeMilestone> _milestones({bool secondClaimed = false}) => [
  ChallengeMilestone(target: 20, label: 'Tier 1', icon: Icons.star_rounded),
  ChallengeMilestone(
    target: 50,
    label: 'Tier 2',
    icon: Icons.diamond_rounded,
    isClaimed: secondClaimed,
  ),
  ChallengeMilestone(
    target: 100,
    label: 'Grand prize',
    icon: Icons.emoji_events_rounded,
  ),
];

WeeklyChallengeCard _card({
  int current = 35,
  int target = 100,
  List<ChallengeMilestone>? milestones,
  DateTime? expiresAt,
  VoidCallback? onTap,
  ValueChanged<int>? onClaimMilestone,
  VoidCallback? onExpired,
  double height = 156,
  double? width,
}) => WeeklyChallengeCard(
  title: 'Weekly Star Race',
  subtitle: 'Collect stars this week',
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 3, hours: 4)),
  currentProgress: current,
  targetProgress: target,
  milestones: milestones ?? _milestones(),
  onTap: onTap,
  onClaimMilestone: onClaimMilestone,
  onExpired: onExpired,
  height: height,
  width: width,
);

void main() {
  group('ChallengeMilestone validation', () {
    test('rejects non-positive target or empty label', () {
      expect(
        () => ChallengeMilestone(target: 0, label: 'Tier'),
        throwsArgumentError,
      );
      expect(
        () => ChallengeMilestone(target: 5, label: '  '),
        throwsArgumentError,
      );
    });
  });

  group('WeeklyChallengeCard validation', () {
    test('rejects invalid title, progress, or dimensions', () {
      final future = DateTime.now().add(const Duration(days: 1));
      expect(
        () => WeeklyChallengeCard(
          title: '',
          expiresAt: future,
          currentProgress: 0,
          targetProgress: 10,
          milestones: _milestones(),
        ),
        throwsArgumentError,
      );
      expect(
        () => WeeklyChallengeCard(
          title: 'Challenge',
          expiresAt: future,
          currentProgress: -1,
          targetProgress: 10,
          milestones: _milestones(),
        ),
        throwsArgumentError,
      );
      expect(
        () => WeeklyChallengeCard(
          title: 'Challenge',
          expiresAt: future,
          currentProgress: 0,
          targetProgress: 0,
          milestones: _milestones(),
        ),
        throwsArgumentError,
      );
      expect(
        () => WeeklyChallengeCard(
          title: 'Challenge',
          expiresAt: future,
          currentProgress: 0,
          targetProgress: 10,
          milestones: _milestones(),
          height: double.infinity,
        ),
        throwsArgumentError,
      );
    });

    test('requires 1-3 strictly increasing milestones within target', () {
      final future = DateTime.now().add(const Duration(days: 1));
      WeeklyChallengeCard valid({required List<ChallengeMilestone> points}) =>
          WeeklyChallengeCard(
            title: 'Challenge',
            expiresAt: future,
            currentProgress: 0,
            targetProgress: 100,
            milestones: points,
          );

      expect(() => valid(points: const []), throwsArgumentError);
      expect(
        () => valid(
          points: [
            for (var i = 0; i < 4; i++)
              ChallengeMilestone(target: (i + 1) * 20, label: 'Tier $i'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => valid(
          points: [
            ChallengeMilestone(target: 30, label: 'First'),
            ChallengeMilestone(target: 20, label: 'Second'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => valid(
          points: [ChallengeMilestone(target: 101, label: 'Beyond target')],
        ),
        throwsArgumentError,
      );
    });
  });

  group('WeeklyChallengeCard rendering and interactions', () {
    testWidgets(
      'renders title, day countdown, progress, and milestone labels',
      (tester) async {
        await tester.pumpWidget(_wrap(_card()));
        expect(find.text('Weekly Star Race'), findsOneWidget);
        expect(find.text('Collect stars this week'), findsOneWidget);
        expect(find.textContaining('3d 4h'), findsOneWidget);
        expect(find.text('35/100'), findsOneWidget);
        expect(find.text('Tier 1'), findsOneWidget);
        expect(find.text('Tier 2'), findsOneWidget);
        expect(find.text('Grand prize'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('card tap calls onTap while active', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(_card(onTap: () => taps++)));
      await tester.tap(find.byKey(const ValueKey('weeklyChallengeCardTap')));
      expect(taps, 1);
    });

    testWidgets('milestone claims only when threshold reached and unclaimed', (
      tester,
    ) async {
      final claims = <int>[];
      await tester.pumpWidget(
        _wrap(_card(current: 35, onClaimMilestone: claims.add)),
      );

      final tier1 = find.byKey(const ValueKey('weeklyChallengeClaim_0'));
      final tier2 = find.byKey(const ValueKey('weeklyChallengeClaim_1'));
      final grand = find.byKey(const ValueKey('weeklyChallengeClaim_2'));

      await tester.tap(tier1);
      await tester.tap(tier2);
      await tester.tap(grand);
      expect(claims, [0]);

      // Caller re-passes claimed state; already-claimed milestone stays disabled.
      await tester.pumpWidget(
        _wrap(
          _card(
            current: 100,
            milestones: _milestones(secondClaimed: true),
            onClaimMilestone: claims.add,
          ),
        ),
      );
      await tester.tap(tier2);
      await tester.tap(grand);
      expect(claims, [0, 2]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expiration fires once, keeps card visible, locks callbacks', (
      tester,
    ) async {
      var expiredCalls = 0;
      var taps = 0;
      final endsAt = DateTime.now().add(const Duration(seconds: 3));

      await tester.pumpWidget(
        _wrap(
          _card(
            expiresAt: endsAt,
            onTap: () => taps++,
            onExpired: () => expiredCalls++,
            onClaimMilestone: (_) => taps++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));

      expect(expiredCalls, 1);
      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('Weekly Star Race'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('weeklyChallengeCardTap')));
      await tester.tap(find.byKey(const ValueKey('weeklyChallengeClaim_0')));
      expect(taps, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pre-expired challenge notifies once after first frame', (
      tester,
    ) async {
      var expiredCalls = 0;
      await tester.pumpWidget(
        _wrap(
          _card(
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
            onExpired: () => expiredCalls++,
          ),
        ),
      );
      await tester.pump();
      expect(expiredCalls, 1);
      expect(find.text('Ended'), findsOneWidget);
    });

    testWidgets('changed expiresAt resets countdown and expiry state', (
      tester,
    ) async {
      var expiredCalls = 0;
      Widget build(DateTime end) =>
          _wrap(_card(expiresAt: end, onExpired: () => expiredCalls++));

      await tester.pumpWidget(
        build(DateTime.now().add(const Duration(seconds: 2))),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(expiredCalls, 1);
      expect(find.text('Ended'), findsOneWidget);

      await tester.pumpWidget(
        build(DateTime.now().add(const Duration(hours: 1))),
      );
      expect(find.text('Ended'), findsNothing);
      expect(find.textContaining('01:00:00'), findsOneWidget);
    });

    testWidgets('Reduced Motion makes progress fill duration zero', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_card(current: 10), reduced: true));
      final fill = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('weeklyChallengeProgressFill')),
      );
      expect(fill.duration, Duration.zero);
    });

    testWidgets('semantics announce active and expired challenge', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(_card(current: 40)));
      var semantics = tester.getSemantics(
        find.byKey(const ValueKey('weeklyChallengeCardTap')),
      );
      expect(semantics.label, contains('Weekly Star Race'));
      expect(semantics.label, contains('40 of 100 progress'));

      await tester.pumpWidget(
        _wrap(
          _card(expiresAt: DateTime.now().subtract(const Duration(seconds: 1))),
        ),
      );
      semantics = tester.getSemantics(
        find.byKey(const ValueKey('weeklyChallengeCardTap')),
      );
      expect(semantics.label, contains('ended'));
      handle.dispose();
    });

    testWidgets('app interruption paused/resumed keeps countdown valid', (
      tester,
    ) async {
      var expiredCalls = 0;
      await tester.pumpWidget(
        _wrap(
          _card(
            expiresAt: DateTime.now().add(const Duration(seconds: 5)),
            onExpired: () => expiredCalls++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:04'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(WeeklyChallengeCard), findsOneWidget);
      expect(expiredCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'unmount during countdown cancels timer without later callback',
      (tester) async {
        var expiredCalls = 0;
        await tester.pumpWidget(
          _wrap(
            _card(
              expiresAt: DateTime.now().add(const Duration(seconds: 2)),
              onExpired: () => expiredCalls++,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
        expect(expiredCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
