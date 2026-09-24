import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
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

  testWidgets(
    'ENH-17: Reduce Motion bật → sweep ticker không chạy, block vẫn hiện tĩnh',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: Material(
              child: ShimmerPlaceholder(
                width: 120,
                height: 20,
                duration: Duration(milliseconds: 1000),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gradientAt0 = _decorationOf(tester).gradient! as LinearGradient;
      await tester.pump(const Duration(milliseconds: 250));
      final gradientAt250 = _decorationOf(tester).gradient! as LinearGradient;

      expect(gradientAt250.begin, equals(gradientAt0.begin));
      expect(find.byType(ShimmerPlaceholder), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ENH-37: có Semantics label "Loading", excludeSemantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Material(child: ShimmerPlaceholder())),
    );

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    handle.dispose();
  });

  group('BUG-73: didUpdateWidget resync duration khi đang chạy', () {
    double tOf(WidgetTester tester) {
      final gradient = _decorationOf(tester).gradient! as LinearGradient;
      // build(): begin = Alignment(-3 + 6*t, 0) -> t = (begin.x + 3) / 6.
      return ((gradient.begin as Alignment).x + 3) / 6;
    }

    testWidgets(
      'đổi duration khi đang chạy -> loop restart dùng đúng duration MỚI '
      '(không kẹt ở duration cũ)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: ShimmerPlaceholder(
                width: 120,
                height: 20,
                duration: Duration(seconds: 10),
              ),
            ),
          ),
        );
        await tester.pump();

        // Rebuild CÙNG cây widget (không đổi key) với duration nhỏ hẳn —
        // trigger didUpdateWidget ngay tại t gần 0.
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: ShimmerPlaceholder(
                width: 120,
                height: 20,
                duration: Duration(milliseconds: 100),
              ),
            ),
          ),
        );

        // Nếu bug còn (duration cũ 10s vẫn giữ nguyên): sau 50ms, t ~
        // 50/10000 ~ 0.005. Nếu đã fix (loop restart đúng 100ms mới): sau
        // 50ms (nửa chu kỳ mới), t ~ 0.5.
        await tester.pump(const Duration(milliseconds: 50));

        expect(tOf(tester), closeTo(0.5, 0.15));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'không đổi duration -> hành vi giữ nguyên như cũ (không bị restart '
      'thừa mỗi lần rebuild)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: ShimmerPlaceholder(
                width: 120,
                height: 20,
                duration: Duration(seconds: 1),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final tBefore = tOf(tester);

        // Rebuild CÙNG duration (không đổi gì) — không được restart loop.
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: ShimmerPlaceholder(
                width: 120,
                height: 20,
                duration: Duration(seconds: 1),
              ),
            ),
          ),
        );

        expect(tOf(tester), closeTo(tBefore, 0.01));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ENH-49: shape/baseColor/highlightColor', () {
    testWidgets(
      'không truyền → giữ nguyên default cũ (rectangle, borderRadius, cardAlt/card)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Material(child: ShimmerPlaceholder())),
        );

        final decoration = _decorationOf(tester);
        expect(decoration.shape, BoxShape.rectangle);
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect(decoration.color, NeonTheme.cardAlt);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shape: BoxShape.circle → decoration là hình tròn, KHÔNG có borderRadius (tránh assertion lỗi)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: ShimmerPlaceholder(
                width: 48,
                height: 48,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

        final decoration = _decorationOf(tester);
        expect(decoration.shape, BoxShape.circle);
        expect(decoration.borderRadius, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'baseColor/highlightColor tuỳ chỉnh → áp dụng đúng vào color/gradient',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: ShimmerPlaceholder(
                baseColor: Colors.indigo,
                highlightColor: Colors.amber,
              ),
            ),
          ),
        );

        final decoration = _decorationOf(tester);
        expect(decoration.color, Colors.indigo);
        final gradient = decoration.gradient! as LinearGradient;
        expect(gradient.colors, [Colors.indigo, Colors.amber, Colors.indigo]);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
