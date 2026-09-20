import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/pressable_scale.dart';

void main() {
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
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.94,
    );

    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
  });

  testWidgets(
    'ENH-22: nhấn xuống dùng easeOut, thả tay dùng easeOutBack (nảy nhẹ)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: PressableScale(onTap: () {}, child: const Text('X')),
          ),
        ),
      );

      // Chưa nhấn (trạng thái nghỉ) khớp curve của chiều "thả tay".
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).curve,
        Curves.easeOutBack,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).curve,
        Curves.easeOut,
      );

      await gesture.up();
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).curve,
        Curves.easeOutBack,
      );
    },
  );

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

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
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

    testWidgets('Space kích hoạt onTap khi đang focus (đúng D-pad/gamepad "A" ánh xạ)', (
      tester,
    ) async {
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
    });

    testWidgets('disabled (onTap null) -> KHÔNG focusable, không có Focus node nào gắn', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: PressableScale(onTap: null, child: Text('X'))),
        ),
      );

      expect(find.descendant(of: find.byType(PressableScale), matching: find.byType(Focus)), findsNothing);
    });

    testWidgets(
      'PHÁT HIỆN THẬT: touch-only user không bao giờ thấy focus ring dù widget đang focus '
      '(FocusHighlightMode.touch, giả lập đúng platform cảm ứng)',
      (tester) async {
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: PressableScale(focusNode: focusNode, onTap: () {}, child: const Text('X')),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();

        final decoration = tester
            .widget<DecoratedBox>(find.byType(DecoratedBox).first)
            .decoration as BoxDecoration;
        expect(decoration.border, isNull);
        focusNode.dispose();
      },
    );

    testWidgets(
      'focus ring HIỆN khi FocusHighlightMode.traditional (bàn phím/gamepad/chuột)',
      (tester) async {
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

        final focusNode = FocusNode();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: PressableScale(focusNode: focusNode, onTap: () {}, child: const Text('X')),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();

        final decoration = tester
            .widget<DecoratedBox>(find.byType(DecoratedBox).first)
            .decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
        focusNode.dispose();
      },
    );

    testWidgets('tap gesture vẫn hoạt động bình thường sau khi thêm focus wiring (regression)', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: PressableScale(onTap: () => tapped = true, child: const Text('X')),
          ),
        ),
      );

      await tester.tap(find.text('X'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

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
