import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';

void main() {
  testWidgets(
    'CurrencyCounter số nhỏ hiển thị qua fmtNum (có dấu phân cách)',
    (tester) async {
      const value = 500;
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: CurrencyCounter(value: value)),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(fmtNum(value)), findsOneWidget);
    },
  );

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
}
