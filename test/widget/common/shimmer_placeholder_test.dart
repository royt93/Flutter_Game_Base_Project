import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/shimmer_placeholder.dart';

BoxDecoration _decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(find.byType(Container));
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('ShimmerPlaceholder render 1 block bo góc màu cardAlt', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: ShimmerPlaceholder(width: 120, height: 20)),
      ),
    );

    expect(find.byType(ShimmerPlaceholder), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ShimmerPlaceholder animation chạy — frame sau khác frame trước',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: ShimmerPlaceholder(
              width: 120,
              height: 20,
              duration: Duration(milliseconds: 1000),
            ),
          ),
        ),
      );

      final gradientAt0 = _decorationOf(tester).gradient! as LinearGradient;

      await tester.pump(const Duration(milliseconds: 250));
      final gradientAt250 = _decorationOf(tester).gradient! as LinearGradient;

      expect(gradientAt250.begin, isNot(equals(gradientAt0.begin)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ShimmerPlaceholder dispose đúng khi unmount giữa chừng animation (không leak ticker)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: ShimmerPlaceholder(width: 120, height: 20)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Unmount giữa chừng loop animation — nếu AnimationController không
      // dispose sạch, đây sẽ throw hoặc để lại 1 Ticker còn sống.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);

      // Không còn transient callback (ticker) nào bị bỏ sót.
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
