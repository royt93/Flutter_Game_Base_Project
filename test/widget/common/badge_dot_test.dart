import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/badge_dot.dart';

void main() {
  testWidgets('BadgeDot dùng size/color mặc định (NeonTheme.red, 10)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Material(child: BadgeDot())),
    );

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 10);
    expect(container.constraints?.maxHeight, 10);

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, NeonTheme.red);
    expect(decoration.shape, BoxShape.circle);

    expect(tester.takeException(), isNull);
  });

  testWidgets('BadgeDot dùng size/color tuỳ chỉnh khi được truyền', (
    tester,
  ) async {
    const customColor = Colors.blue;
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: BadgeDot(size: 20, color: customColor)),
      ),
    );

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.constraints?.maxWidth, 20);
    expect(container.constraints?.maxHeight, 20);

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, customColor);
  });

  group('ENH-101: pulse/radar animation', () {
    testWidgets('pulse scales around rest while radar paints expanding rings', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: BadgeDot(pulse: true, radar: true)),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('badgeRadarPainter')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 750));
      final scale = tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .entry(0, 0);
      expect(scale, greaterThan(1.2));
      final painter = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('badgeRadarPainter')),
      );
      expect(painter.painter, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reducedMotion shows static dot without ticker/painter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: Material(child: BadgeDot(pulse: true, radar: true)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('badgeRadarPainter')), findsNothing);
      expect(find.byType(Container), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabling animation flags stops controller cleanly', (
      tester,
    ) async {
      var enabled = true;
      late StateSetter setEnabled;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setEnabled = setState;
                return BadgeDot(pulse: enabled, radar: enabled);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('badgeRadarPainter')), findsOneWidget);
      setEnabled(() => enabled = false);
      await tester.pump();
      expect(find.byKey(const ValueKey('badgeRadarPainter')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('ENH-37: Semantics', () {
    testWidgets(
      'decorative — bị ExcludeSemantics, không tạo semantics node/label riêng',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(home: Material(child: BadgeDot())),
        );

        expect(find.byType(ExcludeSemantics), findsWidgets);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );

    testWidgets(
      'khi lồng trong Stack cùng icon của caller, icon vẫn giữ label riêng, dot không thêm label rác',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Stack(
                children: [
                  Semantics(label: 'Mail', child: const Icon(Icons.mail)),
                  const Positioned(top: -2, right: -2, child: BadgeDot()),
                ],
              ),
            ),
          ),
        );

        final data = tester.getSemantics(find.bySemanticsLabel('Mail'));
        expect(data.label, 'Mail');
        handle.dispose();
      },
    );
  });
}
