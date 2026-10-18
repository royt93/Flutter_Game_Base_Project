import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget subject({
  String reward = 'Star Chest',
  String remaining = '2 wins to go',
  double? progress = 0.6,
  bool ready = false,
  VoidCallback? onTap,
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
          padding: const EdgeInsets.all(16),
          child: NextRewardTeaserChip(
            rewardLabel: reward,
            remainingText: remaining,
            progress: progress,
            ready: ready,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates labels, progress and semantic label at runtime', () {
    NextRewardTeaserChip make({
      String reward = 'Chest',
      String remaining = '2 to go',
      String ready = 'Claim',
      double? progress,
      String? semantic,
    }) => NextRewardTeaserChip(
      rewardLabel: reward,
      remainingText: remaining,
      readyLabel: ready,
      progress: progress,
      semanticLabel: semantic,
      onTap: () {},
    );

    expect(() => make(reward: ' '), throwsArgumentError);
    expect(() => make(remaining: ' '), throwsArgumentError);
    expect(() => make(ready: ' '), throwsArgumentError);
    expect(() => make(semantic: ' '), throwsArgumentError);
    expect(() => make(progress: -0.01), throwsArgumentError);
    expect(() => make(progress: 1.01), throwsArgumentError);
    expect(() => make(progress: double.nan), throwsArgumentError);
    expect(() => make(progress: double.infinity), throwsArgumentError);
    expect(() => make(progress: 0), returnsNormally);
    expect(() => make(progress: 1), returnsNormally);
  });

  testWidgets('in-progress shows reward, remaining text and bar', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    expect(find.text('Star Chest'), findsOneWidget);
    expect(find.text('2 wins to go'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('nextRewardChipDot')), findsNothing);
  });

  testWidgets('no progress hides the bar', (tester) async {
    await tester.pumpWidget(subject(progress: null));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('ready swaps remaining text for the ready label and hides bar', (
    tester,
  ) async {
    await tester.pumpWidget(subject(ready: true));
    expect(find.text('Claim'), findsOneWidget);
    expect(find.text('2 wins to go'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('nextRewardChipDot')), findsOneWidget);
  });

  testWidgets('tap routes to caller with a 48dp target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(subject(onTap: () => taps++));
    final target = find.byKey(const ValueKey('nextRewardChipTap'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    expect(taps, 1);
  });

  testWidgets('semantics name the reward and the remaining or ready state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(subject());
      var node = tester.getSemantics(find.byType(NextRewardTeaserChip));
      expect(node.label, 'Star Chest, 2 wins to go');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.pumpWidget(subject(ready: true));
      node = tester.getSemantics(find.byType(NextRewardTeaserChip));
      expect(node.label, 'Star Chest, Claim');
    } finally {
      handle.dispose();
    }
  });

  testWidgets('long text stays on one line with ellipsis', (tester) async {
    await tester.pumpWidget(
      subject(
        reward: 'An Extraordinarily Long Reward Name That Will Not Fit',
        remaining: 'Only a very large number of wins are left to go',
      ),
    );
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp, 2x text, long text and RTL keep layout intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(
        reward: 'An Extraordinarily Long Reward Name That Will Not Fit',
        remaining: 'Only a very large number of wins are left to go',
        scale: 2,
        direction: TextDirection.rtl,
      ),
    );
    expect(
      Directionality.of(tester.element(find.byType(NextRewardTeaserChip))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid toggling between in-progress and ready leaves no ticker', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(subject(ready: i.isEven, progress: i / 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Claim'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion: label still swaps, no pulse ticker runs', (
    tester,
  ) async {
    await tester.pumpWidget(subject(ready: true, reducedMotion: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Claim'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('ready state pulses when motion is allowed', (tester) async {
    await tester.pumpWidget(subject(ready: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });
}
