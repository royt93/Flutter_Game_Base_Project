import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget subject({
  int level = 5,
  int xp = 50,
  int? next = 100,
  String? title,
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
          child: XpLevelHeader(
            level: level,
            currentXp: xp,
            xpForNextLevel: next,
            title: title,
            onTap: onTap,
          ),
        ),
      ),
    ),
  ),
);

double barValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

void main() {
  test('validates level, xp, next-level and text at runtime', () {
    final bad = <XpLevelHeader Function()>[
      () => XpLevelHeader(level: 0, currentXp: 0, xpForNextLevel: 10),
      () => XpLevelHeader(level: 1, currentXp: -1, xpForNextLevel: 10),
      () => XpLevelHeader(level: 1, currentXp: 0, xpForNextLevel: 0),
      () => XpLevelHeader(level: 1, currentXp: 0, xpForNextLevel: -5),
      () => XpLevelHeader(level: 1, currentXp: 11, xpForNextLevel: 10),
      () => XpLevelHeader(level: 1, currentXp: 0, levelLabel: ' '),
      () => XpLevelHeader(level: 1, currentXp: 0, maxLabel: ' '),
      () => XpLevelHeader(level: 1, currentXp: 0, title: ' '),
      () => XpLevelHeader(level: 1, currentXp: 0, xpText: ' '),
      () => XpLevelHeader(level: 1, currentXp: 0, semanticLabel: ' '),
    ];
    for (final create in bad) {
      expect(create, throwsArgumentError);
    }
  });

  testWidgets('shows 0 XP, mid, almost-full and exactly-full states', (
    tester,
  ) async {
    for (final (xp, expected) in [
      (0, 0.0),
      (50, 0.5),
      (99, 0.99),
      (100, 1.0),
    ]) {
      await tester.pumpWidget(subject(xp: xp));
      await tester.pump(const Duration(seconds: 1));
      expect(barValue(tester), closeTo(expected, 0.0001));
      expect(find.text('$xp/100'), findsOneWidget);
    }
    expect(find.text('Lv 5'), findsOneWidget);
  });

  testWidgets('max level shows MAX with a full bar', (tester) async {
    await tester.pumpWidget(subject(level: 50, xp: 7, next: null));
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('7/null'), findsNothing);
    expect(barValue(tester), 1.0);
  });

  testWidgets('shows title and caller-formatted xp text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: XpLevelHeader(
          level: 2,
          currentXp: 1200,
          xpForNextLevel: 2000,
          title: 'Explorer',
          xpText: '1.2K / 2K',
          levelLabel: 'Cấp',
        ),
      ),
    );
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('1.2K / 2K'), findsOneWidget);
    expect(find.text('Cấp 2'), findsOneWidget);
  });

  testWidgets('mount does not animate, later XP change does', (tester) async {
    await tester.pumpWidget(subject(xp: 50));
    expect(tester.binding.transientCallbackCount, 0);
    expect(barValue(tester), 0.5);

    await tester.pumpWidget(subject(xp: 90));
    await tester.pump(const Duration(milliseconds: 100));
    final mid = barValue(tester);
    expect(mid, greaterThan(0.5));
    expect(mid, lessThan(0.9));
    await tester.pump(const Duration(seconds: 1));
    expect(barValue(tester), closeTo(0.9, 0.0001));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion jumps straight to the target', (tester) async {
    await tester.pumpWidget(subject(xp: 10, reducedMotion: true));
    await tester.pumpWidget(subject(xp: 90, reducedMotion: true));
    await tester.pump();
    expect(barValue(tester), closeTo(0.9, 0.0001));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('tap routes to caller with a 48dp target, absent without onTap', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    expect(find.byKey(const ValueKey('xpLevelHeaderTap')), findsNothing);

    var taps = 0;
    await tester.pumpWidget(subject(onTap: () => taps++));
    final target = find.byKey(const ValueKey('xpLevelHeaderTap'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    expect(taps, 1);
  });

  testWidgets('semantics report level, xp and percent', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(subject(title: 'Explorer', onTap: () {}));
      expect(
        tester.getSemantics(find.byType(XpLevelHeader)),
        matchesSemantics(
          label: 'Explorer, Level 5, 50 of 100 XP, 50 percent',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.pumpWidget(subject(level: 9, next: null, xp: 0));
      expect(
        tester.getSemantics(find.byType(XpLevelHeader)),
        matchesSemantics(label: 'Level 9, max level'),
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp, 2x text, long title and RTL keep layout intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(
        level: 123,
        xp: 99999,
        next: 100000,
        title: 'The Extraordinarily Long Title Of A Very Dedicated Player',
        onTap: () {},
        scale: 2,
        direction: TextDirection.rtl,
      ),
    );
    expect(
      Directionality.of(tester.element(find.byType(XpLevelHeader))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid XP growth then level change, final value is correct', (
    tester,
  ) async {
    await tester.pumpWidget(subject(level: 5, xp: 0));
    for (var i = 1; i <= 10; i++) {
      await tester.pumpWidget(subject(level: 5, xp: i * 9));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpWidget(subject(level: 6, xp: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Lv 6'), findsOneWidget);
    expect(barValue(tester), closeTo(0.05, 0.0001));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
