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
}
