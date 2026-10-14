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
}
