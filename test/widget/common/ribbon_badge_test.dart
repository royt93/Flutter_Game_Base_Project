import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/ribbon_badge.dart';

void main() {
  // x-scale (m11) của ma trận — không dùng `getMaxScaleOnAxis()` (đã verify
  // qua debug script ở ENH-31/32 trong session này: trả sai giá trị cho ma
  // trận scale thuần), đọc trực tiếp phần tử ma trận thay thế.
  double ribbonScaleOf(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(const Key('ribbonBadgeScale')))
      .transform
      .storage[0];

  testWidgets(
    'IDEA-27: pop-in — scale < 1 ngay lúc mount, đạt 1.0 khi settle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: RibbonBadge(text: 'SALE', child: Container()),
          ),
        ),
      );

      expect(ribbonScaleOf(tester), lessThan(1.0));

      await tester.pumpAndSettle();
      expect(ribbonScaleOf(tester), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-27: dùng gradient thay vì màu phẳng',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: RibbonBadge(text: 'SALE', child: Container()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(RibbonBadge),
              matching: find.byType(Container),
            )
            .last,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isNotNull);
      expect(decoration.gradient!.colors.length, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'IDEA-27: Reduce Motion bật → không pop, scale = 1.0 ngay',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: RibbonBadge(text: 'SALE', child: Container()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(ribbonScaleOf(tester), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-38: RTL', () {
    testWidgets(
      'LTR: ribbon nằm ở nửa bên phải của child, góc xoay dương (pi/4)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: SizedBox(
                width: 200,
                height: 100,
                child: RibbonBadge(text: 'SALE', child: Container()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final badgeRect = tester.getRect(find.byType(RibbonBadge));
        final textRect = tester.getRect(find.text('SALE'));
        expect(textRect.center.dx, greaterThan(badgeRect.center.dx));

        final rotate = tester.widgetList<Transform>(find.byType(Transform)).first;
        expect(rotate.transform.getRotation().entry(1, 0), greaterThan(0));
      },
    );

    testWidgets(
      'RTL: ribbon nằm ở nửa bên TRÁI (đảo ngược so với LTR), góc xoay đảo dấu',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: 200,
                  height: 100,
                  child: RibbonBadge(text: 'SALE', child: Container()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final badgeRect = tester.getRect(find.byType(RibbonBadge));
        final textRect = tester.getRect(find.text('SALE'));
        expect(textRect.center.dx, lessThan(badgeRect.center.dx));

        final rotate = tester.widgetList<Transform>(find.byType(Transform)).first;
        expect(rotate.transform.getRotation().entry(1, 0), lessThan(0));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
