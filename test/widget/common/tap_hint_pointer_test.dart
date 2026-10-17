import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tap_hint_pointer.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(home: Scaffold(body: child)),
);

Offset _handCenter(WidgetTester tester) =>
    tester.getCenter(find.byKey(const ValueKey('tapHintHand')));

void main() {
  group('tapHintPointerOffsetAt', () {
    const a = Offset(10, 20);
    const b = Offset(110, 20);

    test('tap bobs down and returns to start', () {
      Offset at(double t) =>
          tapHintPointerOffsetAt(gesture: TapHintGesture.tap, t: t, start: a);
      expect(at(0), a);
      expect(at(0.5).dy, greaterThan(a.dy));
      expect(at(0.5).dx, a.dx);
      expect(at(1).dy, closeTo(a.dy, 1e-9));
    });

    test('swipe glides start to end then rests', () {
      Offset at(double t) => tapHintPointerOffsetAt(
        gesture: TapHintGesture.swipe,
        t: t,
        start: a,
        end: b,
      );
      expect(at(0), a);
      expect(at(0.35).dx, inExclusiveRange(a.dx, b.dx));
      expect(at(0.7), b);
      expect(at(1), b);
    });
  });

  group('TapHintPointer validation', () {
    final key = GlobalKey();

    test('requires exactly one of targetKey or position', () {
      expect(() => TapHintPointer(), throwsArgumentError);
      expect(
        () => TapHintPointer(targetKey: key, position: const Offset(1, 1)),
        throwsArgumentError,
      );
    });

    test('swipeTo is required for swipe and invalid for tap', () {
      expect(
        () => TapHintPointer(
          position: const Offset(1, 1),
          gesture: TapHintGesture.swipe,
        ),
        throwsArgumentError,
      );
      expect(
        () => TapHintPointer(
          position: const Offset(1, 1),
          swipeTo: const Offset(5, 5),
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive or non-finite size', () {
      expect(
        () => TapHintPointer(position: const Offset(1, 1), size: 0),
        throwsArgumentError,
      );
      expect(
        () => TapHintPointer(position: const Offset(1, 1), size: double.nan),
        throwsArgumentError,
      );
    });
  });

  group('TapHintPointer rendering', () {
    testWidgets('explicit position places the ripple at that point', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Positioned.fill(
                child: TapHintPointer(position: const Offset(150, 250)),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getCenter(find.byKey(const ValueKey('tapHintRipple'))).dx,
        closeTo(150, 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('targetKey centers the ripple on the target widget', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Positioned(
                left: 40,
                top: 100,
                child: SizedBox(key: key, width: 120, height: 60),
              ),
              Positioned.fill(child: TapHintPointer(targetKey: key)),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final ripple = tester.getCenter(
        find.byKey(const ValueKey('tapHintRipple')),
      );
      final target = tester.getCenter(find.byKey(key));
      expect(ripple.dx, closeTo(target.dx, 0.5));
      expect(ripple.dy, closeTo(target.dy, 0.5));
    });

    testWidgets('unattached targetKey renders nothing without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Positioned.fill(child: TapHintPointer(targetKey: GlobalKey())),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('tapHintHand')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('visible false hides the pointer', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Positioned.fill(
                child: TapHintPointer(
                  position: const Offset(50, 50),
                  visible: false,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('tapHintHand')), findsNothing);
    });

    testWidgets('swipe moves the hand toward swipeTo', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Positioned.fill(
                child: TapHintPointer(
                  position: const Offset(50, 200),
                  gesture: TapHintGesture.swipe,
                  swipeTo: const Offset(250, 200),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final before = _handCenter(tester).dx;
      await tester.pump(const Duration(milliseconds: 500));
      final mid = _handCenter(tester).dx;
      await tester.pump(const Duration(milliseconds: 300));
      final late = _handCenter(tester).dx;
      expect(mid, greaterThan(before));
      expect(late, greaterThan(mid));
    });

    testWidgets('does not intercept taps on the widget underneath', (
      tester,
    ) async {
      var taps = 0;
      final key = GlobalKey();
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Center(
                child: GestureDetector(
                  key: key,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
              Positioned.fill(child: TapHintPointer(targetKey: key)),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byKey(key)));
      expect(taps, 1);
    });

    testWidgets('Reduced Motion keeps the pointer static', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Positioned.fill(
                child: TapHintPointer(
                  position: const Offset(50, 200),
                  gesture: TapHintGesture.swipe,
                  swipeTo: const Offset(250, 200),
                ),
              ),
            ],
          ),
          reduced: true,
        ),
      );
      await tester.pump();
      final first = _handCenter(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_handCenter(tester), first);
    });

    testWidgets('disposing mid-animation does not throw', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Stack(
            children: [
              Positioned.fill(
                child: TapHintPointer(position: const Offset(50, 50)),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
