import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/presentation/widgets/coin_fly_overlay.dart';

void main() {
  testWidgets('renders without crash and calls onDone after animation', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(home: CoinFlyOverlay(count: 3, onDone: () => done = true)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(done, isFalse);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(tester.takeException(), isNull);
    expect(done, isTrue);
  });
}
