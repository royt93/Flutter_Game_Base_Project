import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/reward_popup.dart';

void main() {
  testWidgets('RewardPopup burst animation runs without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: RewardPopup(
              title: 'Level Complete!',
              message: 'Great job',
              icon: Icons.star_rounded,
              color: NeonTheme.gold,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ENH-17: Reduce Motion bật → không burst confetti, panel hiện ngay không cần chờ',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: Center(
                child: RewardPopup(
                  title: 'Level Complete!',
                  message: 'Great job',
                  icon: Icons.star_rounded,
                  color: NeonTheme.gold,
                ),
              ),
            ),
          ),
        ),
      );

      // 1 frame duy nhất — cả entrance (320ms) lẫn burst không cần chờ.
      await tester.pump();

      expect(find.text('Level Complete!'), findsOneWidget);
      final burstPainters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.painter.runtimeType.toString() == '_BurstPainter');
      expect(burstPainters, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-45: onDismiss/dismissLabel', () {
    testWidgets('onDismiss null (mặc định) → không có nút nào thừa', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: RewardPopup(
                title: 'Level Complete!',
                message: 'Great job',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(CommonButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'onDismiss truyền vào hiển thị nút với dismissLabel, tap gọi đúng callback',
      (tester) async {
        var dismissed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: RewardPopup(
                  title: 'Level Complete!',
                  message: 'Great job',
                  onDismiss: () => dismissed = true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        final button = tester.widget<CommonButton>(find.byType(CommonButton));
        expect(button.label, 'Claim');
        await tester.tap(find.byType(CommonButton));
        expect(dismissed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'dismissLabel tuỳ chỉnh hiển thị đúng thay vì "Claim" mặc định',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: Center(
                child: RewardPopup(
                  title: 'Level Complete!',
                  onDismiss: () {},
                  dismissLabel: 'Awesome!',
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        final button = tester.widget<CommonButton>(find.byType(CommonButton));
        expect(button.label, 'Awesome!');
      },
    );
  });
}
