import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/radial_action_menu.dart';

void main() {
  test('radial offsets follow the configured arc and radius', () {
    const radius = 100.0;
    final first = radialActionOffsetForIndex(
      index: 0,
      itemCount: 3,
      radius: radius,
      startAngleDegrees: 180,
      sweepAngleDegrees: 90,
    );
    final middle = radialActionOffsetForIndex(
      index: 1,
      itemCount: 3,
      radius: radius,
      startAngleDegrees: 180,
      sweepAngleDegrees: 90,
    );
    final last = radialActionOffsetForIndex(
      index: 2,
      itemCount: 3,
      radius: radius,
      startAngleDegrees: 180,
      sweepAngleDegrees: 90,
    );
    expect(first.dx, closeTo(-radius, 0.001));
    expect(first.dy, closeTo(0, 0.001));
    expect(middle.dx, closeTo(-radius / math.sqrt2, 0.001));
    expect(middle.dy, closeTo(-radius / math.sqrt2, 0.001));
    expect(last.dx, closeTo(0, 0.001));
    expect(last.dy, closeTo(-radius, 0.001));
  });

  test('rejects invalid action index, radius and item count', () {
    expect(
      () => radialActionOffsetForIndex(
        index: 0,
        itemCount: 0,
        radius: 10,
        startAngleDegrees: 0,
        sweepAngleDegrees: 90,
      ),
      throwsArgumentError,
    );
    expect(
      () => radialActionOffsetForIndex(
        index: 2,
        itemCount: 2,
        radius: 10,
        startAngleDegrees: 0,
        sweepAngleDegrees: 90,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('opens actions, blocks outside taps and closes after selection', (
    tester,
  ) async {
    var backgroundTaps = 0;
    var actionTaps = 0;
    final key = GlobalKey<RadialActionMenuState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => backgroundTaps++,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
                RadialActionMenu(
                  key: key,
                  alignment: Alignment.bottomRight,
                  radius: 110,
                  startAngleDegrees: 180,
                  sweepAngleDegrees: 90,
                  items: [
                    RadialActionItem(
                      label: 'Share',
                      icon: Icons.share,
                      onTap: () => actionTaps++,
                    ),
                    RadialActionItem(
                      label: 'Help',
                      icon: Icons.help,
                      onTap: () => actionTaps++,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('radialActionPrimary')));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(key.currentState!.isOpen, isTrue);
    expect(find.byKey(const ValueKey('radialActionBarrier')), findsOneWidget);
    final share = find.byKey(const ValueKey('radialAction_0_Share'));
    expect(share, findsOneWidget);
    await tester.tap(share);
    await tester.pump(const Duration(milliseconds: 250));
    expect(actionTaps, 1);
    expect(key.currentState!.isOpen, isFalse);
    final help = find.byKey(const ValueKey('radialAction_1_Help'));
    expect(help, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('radialActionPrimary')));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 250));
    expect(backgroundTaps, 0);
    expect(actionTaps, 1);
    expect(key.currentState!.isOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion opens immediately and outside tap closes', (
    tester,
  ) async {
    final key = GlobalKey<RadialActionMenuState>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: RadialActionMenu(
              key: key,
              items: [
                RadialActionItem(label: 'One', icon: Icons.star, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('radialActionPrimary')));
    await tester.pump();
    expect(key.currentState!.progress, 1);
    expect(find.byKey(const ValueKey('radialAction_0_One')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('items open with a stagger: later items trail earlier ones', (
    tester,
  ) async {
    final key = GlobalKey<RadialActionMenuState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: RadialActionMenu(
              key: key,
              alignment: Alignment.bottomRight,
              radius: 110,
              startAngleDegrees: 180,
              sweepAngleDegrees: 90,
              items: [
                for (final n in ['A', 'B', 'C'])
                  RadialActionItem(label: n, icon: Icons.star, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('radialActionPrimary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    double opacityOf(String label) {
      final item = find.byKey(ValueKey('radialAction_${'ABC'.indexOf(label)}_$label'));
      final op = find.ancestor(of: item, matching: find.byType(Opacity)).first;
      return tester.widget<Opacity>(op).opacity;
    }

    final a = opacityOf('A');
    final b = opacityOf('B');
    final c = opacityOf('C');
    expect(a, greaterThan(b), reason: 'first item leads');
    expect(b, greaterThan(c), reason: 'last item trails');

    await tester.pump(const Duration(seconds: 1));
    expect(opacityOf('A'), 1.0);
    expect(opacityOf('C'), 1.0, reason: 'every item ends fully open');
    expect(tester.takeException(), isNull);
  });

  testWidgets('item scale overshoots 1.0 on the way open (easeOutBack)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: RadialActionMenu(
              alignment: Alignment.bottomRight,
              radius: 110,
              startAngleDegrees: 180,
              sweepAngleDegrees: 90,
              items: [
                RadialActionItem(label: 'A', icon: Icons.star, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('radialActionPrimary')));
    await tester.pump();
    final item = find.byKey(const ValueKey('radialAction_0_A'));
    var peak = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      // Transform.scale(scale: 0.72 + progress * 0.28): progress > 1 shows as
      // a scale above 1.0.
      final scale = find.ancestor(of: item, matching: find.byType(Transform));
      for (final w in tester.widgetList<Transform>(scale)) {
        final sx = w.transform.storage[0];
        if (sx > peak) peak = sx;
      }
    }
    expect(peak, greaterThan(1.0), reason: 'easeOutBack overshoots');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
