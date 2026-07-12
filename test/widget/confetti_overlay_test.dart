import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/presentation/widgets/confetti_overlay.dart';

void main() {
  testWidgets('renders confetti and runs full animation without crash', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ConfettiOverlay(count: 5)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.pump(const Duration(milliseconds: 2700));
    expect(tester.takeException(), isNull);
  });
}
