import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/throttle.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

void main() {
  testWidgets(
    'CommonButton.onTap bọc throttled() chặn rage-tap double-fire',
    (tester) async {
      var calls = 0;
      final onTap = throttled(
        () => calls++,
        window: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(label: 'Buy', onTap: onTap),
          ),
        ),
      );

      // Rage-tap: nhiều lần liên tiếp không có delay thật giữa các lần.
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byType(CommonButton));
      }
      await tester.pump();

      expect(calls, 1);
    },
  );
}
