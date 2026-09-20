import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';

void main() {
  testWidgets('CurrencyCounter số nhỏ hiển thị qua fmtNum (có dấu phân cách)', (
    tester,
  ) async {
    const value = 500;
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: CurrencyCounter(value: value)),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(fmtNum(value)), findsOneWidget);
  });

  testWidgets(
    'CurrencyCounter số lớn (idle-game scale) rút gọn qua fmtNumCompact',
    (tester) async {
      const value = 1234567;
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: CurrencyCounter(value: value)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(fmtNumCompact(value)), findsOneWidget);
      expect(find.text(fmtNum(value)), findsNothing);
      expect(find.text('$value'), findsNothing);
    },
  );

  testWidgets(
    'FEAT-17: Reduce Motion bật → đổi giá trị hiển thị ngay, không animation',
    (tester) async {
      var value = 10;
      late StateSetter setValue;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setValue = setState;
                  return CurrencyCounter(value: value);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(fmtNum(10)), findsOneWidget);

      setValue(() => value = 99);
      await tester.pump(); // 1 frame, không chờ 500ms animation.

      expect(find.text(fmtNum(99)), findsOneWidget);
      expect(find.text(fmtNum(10)), findsNothing);
    },
  );

  group('ENH-50: compact', () {
    const value = 12345678;

    testWidgets('compact: true (mặc định) → hiển thị qua fmtNumCompact', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: CurrencyCounter(value: value)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(fmtNumCompact(value)), findsOneWidget);
      expect(find.text(fmtNum(value)), findsNothing);
    });

    testWidgets('compact: false → hiển thị số chính xác qua fmtNum', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: CurrencyCounter(value: value, compact: false)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(fmtNum(value)), findsOneWidget);
      expect(find.text(fmtNumCompact(value)), findsNothing);
    });
  });

  group('ENH-37: Semantics', () {
    testWidgets(
      'label luôn đọc số chính xác (fmtNum) bất kể compact, ở 2 giá trị khác nhau',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(child: CurrencyCounter(value: 1500)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          tester.getSemantics(find.byType(CurrencyCounter)).label,
          fmtNum(1500),
        );

        await tester.pumpWidget(
          const MaterialApp(home: Material(child: CurrencyCounter(value: 250))),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          tester.getSemantics(find.byType(CurrencyCounter)).label,
          fmtNum(250),
        );
        handle.dispose();
      },
    );

    testWidgets('semanticLabel tuỳ chỉnh ghi đè đúng label mặc định', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: CurrencyCounter(value: 100, semanticLabel: 'Gems: 100'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.getSemantics(find.byType(CurrencyCounter)).label,
        'Gems: 100',
      );
      handle.dispose();
    });
  });

  group('ENH-38: RTL', () {
    testWidgets(
      'FittedBox dùng AlignmentDirectional.centerStart (không phải Alignment.centerLeft vật lý)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Material(child: CurrencyCounter(value: 100))),
        );

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.alignment, AlignmentDirectional.centerStart);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'RTL: số bị co lại (scaleDown) vẫn neo bên trong khung, không throw',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: 40,
                  child: CurrencyCounter(value: 999999999),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
