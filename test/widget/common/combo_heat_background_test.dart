import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/combo_heat_background.dart';

const _cool = Color(0xFF0000FF);
const _hot = Color(0xFFFF0000);

// Gradient là [lighter, color] (xem ENH-35) — phần tử cuối luôn chính là
// giá trị lerp(cool, hot, heat) không pha trắng, dùng để so sánh chính xác
// với _cool/_hot như trước khi có gradient.
Color _renderedColor(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(ComboHeatBackground),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).gradient!.colors.last;
}

Widget _wrap(double heat) => MaterialApp(
  home: Material(
    child: ComboHeatBackground(
      heat: heat,
      coolColor: _cool,
      hotColor: _hot,
      child: const SizedBox(width: 40, height: 40),
    ),
  ),
);

void main() {
  testWidgets(
    'ENH-35: render bằng gradient (>=2 màu khác nhau), không phải màu phẳng',
    (tester) async {
      await tester.pumpWidget(_wrap(0.5));
      await tester.pump(const Duration(milliseconds: 400));

      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ComboHeatBackground),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient = (box.decoration as BoxDecoration).gradient;
      expect(gradient, isNotNull);
      expect(gradient!.colors.length, greaterThanOrEqualTo(2));
      expect(gradient.colors.toSet().length, greaterThan(1));
    },
  );

  testWidgets('heat 0.0 renders coolColor', (tester) async {
    await tester.pumpWidget(_wrap(0.0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_renderedColor(tester), _cool);
  });

  testWidgets('heat 1.0 renders hotColor', (tester) async {
    await tester.pumpWidget(_wrap(1.0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_renderedColor(tester), _hot);
  });

  testWidgets('changing heat animates rather than jumping instantly', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(0.0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_renderedColor(tester), _cool);

    await tester.pumpWidget(_wrap(1.0));
    // Partial frame, well before the 300ms transition completes.
    await tester.pump(const Duration(milliseconds: 100));

    final mid = _renderedColor(tester);
    expect(mid, isNot(_cool));
    expect(mid, isNot(_hot));

    await tester.pump(const Duration(milliseconds: 400));
    expect(_renderedColor(tester), _hot);
  });

  testWidgets('FEAT: Reduce Motion bật → đổi heat ngay, không animation', (
    tester,
  ) async {
    var heat = 0.0;
    late StateSetter setHeat;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setHeat = setState;
                return ComboHeatBackground(
                  heat: heat,
                  coolColor: _cool,
                  hotColor: _hot,
                  child: const SizedBox(width: 40, height: 40),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_renderedColor(tester), _cool);

    setHeat(() => heat = 1.0);
    await tester.pump(); // 1 frame, no animation duration to wait out.

    expect(_renderedColor(tester), _hot);
  });
}
