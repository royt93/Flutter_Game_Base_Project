import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/paginated_dots_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(
    child: Center(child: SizedBox(width: 200, height: 40, child: child)),
  ),
);

void main() {
  testWidgets('PaginatedDotsIndicator first of 4 active', (tester) async {
    await tester.pumpWidget(
      _wrap(const PaginatedDotsIndicator(count: 4, currentIndex: 0)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PaginatedDotsIndicator),
      matchesGoldenFile('paginated_dots_indicator_first_of_4.png'),
    );
  });

  testWidgets('PaginatedDotsIndicator last of 4 active', (tester) async {
    await tester.pumpWidget(
      _wrap(const PaginatedDotsIndicator(count: 4, currentIndex: 3)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PaginatedDotsIndicator),
      matchesGoldenFile('paginated_dots_indicator_last_of_4.png'),
    );
  });

  testWidgets('PaginatedDotsIndicator middle of 3 active', (tester) async {
    await tester.pumpWidget(
      _wrap(const PaginatedDotsIndicator(count: 3, currentIndex: 1)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PaginatedDotsIndicator),
      matchesGoldenFile('paginated_dots_indicator_middle_of_3.png'),
    );
  });
}
