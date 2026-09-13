import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/paginated_dots_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(child: Center(child: child)),
);

List<double?> _widths(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
    .map((c) => c.constraints?.maxWidth)
    .toList();

void main() {
  testWidgets('highlights currentIndex bigger than the rest', (tester) async {
    await tester.pumpWidget(
      _wrap(const PaginatedDotsIndicator(count: 4, currentIndex: 1)),
    );

    expect(_widths(tester), [8, 12, 8, 8]);
  });

  testWidgets('rebuilding with a new currentIndex moves the highlight', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PaginatedDotsIndicator(count: 4, currentIndex: 0)),
    );
    expect(_widths(tester), [12, 8, 8, 8]);

    await tester.pumpWidget(
      _wrap(const PaginatedDotsIndicator(count: 4, currentIndex: 3)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(_widths(tester), [8, 8, 8, 12]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom count renders exactly that many dots', (tester) async {
    await tester.pumpWidget(
      _wrap(const PaginatedDotsIndicator(count: 6, currentIndex: 2)),
    );

    expect(_widths(tester), [8, 8, 12, 8, 8, 8]);
  });

  testWidgets(
    'ENH-17: Reduce Motion bật → AnimatedContainer duration = 0 (không tween)',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(const PaginatedDotsIndicator(count: 4, currentIndex: 0)),
        ),
      );

      final durations = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.duration)
          .toSet();
      expect(durations, {Duration.zero});
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-37: Semantics', () {
    testWidgets('label khớp đúng "Page N of M" ở 2 currentIndex khác nhau', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: PaginatedDotsIndicator(count: 4, currentIndex: 0),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(PaginatedDotsIndicator)).label,
        'Page 1 of 4',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: PaginatedDotsIndicator(count: 4, currentIndex: 2),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(PaginatedDotsIndicator)).label,
        'Page 3 of 4',
      );
      handle.dispose();
    });

    testWidgets('semanticLabel tuỳ chỉnh ghi đè đúng label mặc định', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: PaginatedDotsIndicator(
              count: 3,
              currentIndex: 1,
              semanticLabel: 'Onboarding step 2',
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(PaginatedDotsIndicator)).label,
        'Onboarding step 2',
      );
      handle.dispose();
    });
  });
}
