import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/pressable_scale.dart';
import 'package:roy_casual_kit/presentation/widgets/spring_scale_transition.dart';

void main() {
  testWidgets('cancelled gesture restores scale and never fires onTap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: PressableScale(
              onTap: () => taps++,
              child: const ColoredBox(
                color: Colors.blue,
                child: SizedBox(width: 60, height: 60),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      lessThan(1),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      1,
    );
    expect(taps, 0);
  });

  testWidgets('tap invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PressableScale(
            onTap: () => tapped = true,
            child: const Text('X'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('X'));
    expect(tapped, isTrue);
  });

  testWidgets('scales down while pressed, back up on release', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PressableScale(
            onTap: () {},
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      lessThan(1),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      1,
    );
  });

  testWidgets('ENH-100: spring button settles exactly at rest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PressableScale(
            onTap: () {},
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      lessThan(1),
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      greaterThan(0.94),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ENH-100: quick retap interrupts current spring and settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PressableScale(
            onTap: () {},
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PressableScale));
    final first = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    await first.up();
    await tester.pump(const Duration(milliseconds: 40));

    final second = await tester.startGesture(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      lessThan(1),
    );
    await second.cancel();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ENH-100: bouncy preset overshoots then settles at rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: PressableScale(
            onTap: () {},
            springPreset: SpringMotionPreset.bouncy,
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final pressedScale = tester
        .widget<Transform>(find.byType(Transform).first)
        .transform
        .entry(0, 0);
    await gesture.up();
    await tester.pump();
    var peakScale = 1.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final scale = tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0);
      peakScale = math.max(peakScale, scale);
    }
    expect(
      peakScale,
      greaterThan(pressedScale + (1 - pressedScale) * 0.5),
      reason: 'spring should overshoot its rest target after release',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      1,
    );
  });

  test('ENH-100: SpringSimulation converges and becomes done', () {
    final spring = springDescriptionFor(SpringMotionPreset.bouncy);
    final simulation = SpringSimulation(spring, 0, 1, 0);
    var elapsed = 0.0;
    while (elapsed < 10 && !simulation.isDone(elapsed)) {
      elapsed += 0.01;
    }
    expect(simulation.isDone(elapsed), isTrue);
    expect(simulation.x(elapsed), closeTo(1, 0.001));
    expect(simulation.dx(elapsed).abs(), lessThan(0.01));
  });

  test('ENH-100: velocity-aware simulation preserves release velocity', () {
    final spring = springDescriptionFor(SpringMotionPreset.bouncy);
    final simulation = SpringSimulation(spring, 0.94, 1, 4.0);
    expect(simulation.dx(0), 4.0);
    expect(simulation.x(0.01), greaterThan(0.94));
  });

  testWidgets('ENH-100: enabling Reduce Motion mid-press snaps immediately', (
    tester,
  ) async {
    var reducedMotion = false;
    late StateSetter setReducedMotion;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setReducedMotion = setState;
          return MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: MaterialApp(
              home: Material(
                child: PressableScale(
                  onTap: () {},
                  child: const ColoredBox(
                    color: Colors.blue,
                    child: SizedBox(width: 60, height: 60),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      lessThan(1),
    );

    setReducedMotion(() => reducedMotion = true);
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0),
      closeTo(0.94, 0.001),
    );
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ENH-100: spring presets have distinct tuning', (tester) async {
    final bouncy = springDescriptionFor(SpringMotionPreset.bouncy);
    final gentle = springDescriptionFor(SpringMotionPreset.gentle);
    final snappy = springDescriptionFor(SpringMotionPreset.snappy);
    expect(bouncy.damping, lessThan(gentle.damping));
    expect(snappy.stiffness, greaterThan(gentle.stiffness));
  });

  testWidgets(
    'FEAT-17: Reduce Motion bật → chuyển scale tức thời (duration = 0)',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: PressableScale(onTap: () {}, child: const Text('X')),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump();
      expect(
        tester
            .widget<Transform>(find.byType(Transform).first)
            .transform
            .entry(0, 0),
        closeTo(0.94, 0.001),
      );
      await gesture.up();
      await tester.pump();
      expect(
        tester
            .widget<Transform>(find.byType(Transform).first)
            .transform
            .entry(0, 0),
        1,
      );
    },
  );

  testWidgets('disabled (onTap null) ignores tap without crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: PressableScale(onTap: null, child: Text('X'))),
      ),
    );

    await tester.tap(find.text('X'));
    expect(tester.takeException(), isNull);
  });

  group('FEAT-82: keyboard/gamepad activation', () {
    testWidgets('Enter kích hoạt onTap khi đang focus', (tester) async {
      var tapped = false;
      final focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: PressableScale(
              focusNode: focusNode,
              onTap: () => tapped = true,
              child: const Text('X'),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tapped, isTrue);
      focusNode.dispose();
    });

    testWidgets(
      'Space kích hoạt onTap khi đang focus (đúng D-pad/gamepad "A" ánh xạ)',
      (tester) async {
        var tapped = false;
        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: PressableScale(
                focusNode: focusNode,
                onTap: () => tapped = true,
                child: const Text('X'),
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(tapped, isTrue);
        focusNode.dispose();
      },
    );

    testWidgets(
      'disabled (onTap null) -> KHÔNG focusable, không có Focus node nào gắn',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: PressableScale(onTap: null, child: Text('X')),
            ),
          ),
        );

        expect(
          find.descendant(
            of: find.byType(PressableScale),
            matching: find.byType(Focus),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'PHÁT HIỆN THẬT: touch-only user không bao giờ thấy focus ring dù widget đang focus '
      '(FocusHighlightMode.touch, giả lập đúng platform cảm ứng)',
      (tester) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );

        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: PressableScale(
                focusNode: focusNode,
                onTap: () {},
                child: const Text('X'),
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();

        final decoration =
            tester
                    .widget<DecoratedBox>(find.byType(DecoratedBox).first)
                    .decoration
                as BoxDecoration;
        expect(decoration.border, isNull);
        focusNode.dispose();
      },
    );

    testWidgets(
      'focus ring HIỆN khi FocusHighlightMode.traditional (bàn phím/gamepad/chuột)',
      (tester) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );

        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: PressableScale(
                focusNode: focusNode,
                onTap: () {},
                child: const Text('X'),
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();

        final decoration =
            tester
                    .widget<DecoratedBox>(find.byType(DecoratedBox).first)
                    .decoration
                as BoxDecoration;
        expect(decoration.border, isNotNull);
        focusNode.dispose();
      },
    );

    testWidgets(
      'tap gesture vẫn hoạt động bình thường sau khi thêm focus wiring (regression)',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: PressableScale(
                onTap: () => tapped = true,
                child: const Text('X'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('X'));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('autofocus: true tự nhận focus ngay khi build', (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: PressableScale(
              focusNode: focusNode,
              autofocus: true,
              onTap: () {},
              child: const Text('X'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
      focusNode.dispose();
    });
  });
}
