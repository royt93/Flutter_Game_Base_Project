import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';

void main() {
  testWidgets('CurrencyCounter hiển thị số qua fmtNum (có dấu phân cách)', (
    tester,
  ) async {
    const value = 1234567;
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: CurrencyCounter(value: value)),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(fmtNum(value)), findsOneWidget);
    expect(find.text('$value'), findsNothing);
  });
}
