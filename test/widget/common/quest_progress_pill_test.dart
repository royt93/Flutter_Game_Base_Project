import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget subject({
  int completed = 1,
  int total = 3,
  int claimable = 0,
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
          child: QuestProgressPill(
            completed: completed,
            total: total,
            claimableCount: claimable,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates counts, label and semantic label at runtime', () {
    final bad = <QuestProgressPill Function()>[
      () => QuestProgressPill(completed: 0, total: 0, onTap: () {}),
      () => QuestProgressPill(completed: -1, total: 3, onTap: () {}),
      () => QuestProgressPill(completed: 4, total: 3, onTap: () {}),
      () => QuestProgressPill(
        completed: 1,
        total: 3,
        claimableCount: -1,
        onTap: () {},
      ),
      () => QuestProgressPill(
        completed: 1,
        total: 3,
        claimableCount: 2,
        onTap: () {},
      ),
      () => QuestProgressPill(completed: 1, total: 3, label: ' ', onTap: () {}),
      () => QuestProgressPill(
        completed: 1,
        total: 3,
        semanticLabel: ' ',
        onTap: () {},
      ),
    ];
    for (final create in bad) {
      expect(create, throwsArgumentError);
    }
  });

  testWidgets('shows none, partial and complete states', (tester) async {
    await tester.pumpWidget(subject(completed: 0));
    expect(find.text('Quests 0/3'), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

    await tester.pumpWidget(subject(completed: 2));
    expect(find.text('Quests 2/3'), findsOneWidget);

    await tester.pumpWidget(subject(completed: 3));
    expect(find.text('Quests 3/3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsNothing);
  });

  testWidgets('badge hides at 0, shows count and caps at 9+', (tester) async {
    for (final count in [0, 1, 9, 10, 25]) {
      await tester.pumpWidget(
        subject(completed: 30, total: 30, claimable: count),
      );
      final badge = find.byKey(const ValueKey('questProgressPillBadge'));
      if (count == 0) {
        expect(badge, findsNothing);
      } else {
        expect(badge, findsOneWidget);
        expect(find.text(count > 9 ? '9+' : '$count'), findsOneWidget);
      }
    }
  });

  testWidgets('tap routes to caller with 48dp target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(subject(onTap: () => taps++));
    final target = find.byKey(const ValueKey('questProgressPillTap'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    expect(taps, 1);
  });

  testWidgets('semantics report progress and claimable count', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(subject(completed: 2, claimable: 2));
      expect(
        tester.getSemantics(find.byType(QuestProgressPill)),
        matchesSemantics(
          label: 'Quests, 2 of 3 complete, 2 ready to claim',
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp, 2x text and RTL keep layout intact', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(
        completed: 12,
        total: 15,
        claimable: 12,
        scale: 2,
        direction: TextDirection.rtl,
      ),
    );
    expect(
      Directionality.of(tester.element(find.byType(QuestProgressPill))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid progress updates and unmount leave no ticker', (
    tester,
  ) async {
    await tester.pumpWidget(subject(completed: 0, claimable: 0));
    for (var i = 1; i <= 3; i++) {
      await tester.pumpWidget(subject(completed: i, claimable: i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion applies progress immediately', (tester) async {
    await tester.pumpWidget(subject(completed: 0, reducedMotion: true));
    await tester.pumpWidget(subject(completed: 3, reducedMotion: true));
    await tester.pump();
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1.0);
  });
}
