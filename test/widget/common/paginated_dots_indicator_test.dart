import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/paginated_dots_indicator.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Material(child: Center(child: child)));

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
}
