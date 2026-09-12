import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/daily_login_calendar.dart';
import 'package:roy_casual_kit/presentation/widgets/pressable_scale.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

void main() {
  testWidgets('renders cycleLength day slots', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DailyLoginCalendarWidget(
          currentStreakDay: 2,
          claimedDaysInCycle: const {1, 2},
          canClaimToday: true,
          onClaim: () {},
          cycleLength: 5,
        ),
      ),
    );

    for (var day = 1; day <= 5; day++) {
      // Claimed days (1, 2) show a checkmark instead of their number.
      if (day <= 2) continue;
      expect(find.text('$day'), findsOneWidget);
    }
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
  });

  testWidgets('claimed days show as claimed (checkmark, no bare number)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DailyLoginCalendarWidget(
          currentStreakDay: 3,
          claimedDaysInCycle: const {1, 2, 3},
          canClaimToday: false,
          onClaim: () {},
          cycleLength: 7,
        ),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsNothing);
  });

  testWidgets(
    'current day is highlighted and tappable when canClaimToday is true, '
    'tapping it calls onClaim',
    (tester) async {
      var claimed = false;
      await tester.pumpWidget(
        _wrap(
          DailyLoginCalendarWidget(
            currentStreakDay: 2,
            claimedDaysInCycle: const {1, 2},
            canClaimToday: true,
            onClaim: () => claimed = true,
            cycleLength: 7,
          ),
        ),
      );

      // currentStreakDay=2 -> highlight day = 2 % 7 + 1 = 3.
      await tester.tap(find.text('3'));
      await tester.pump();
      expect(claimed, isTrue);
    },
  );

  testWidgets('claim button disabled (no-op) when canClaimToday is false', (
    tester,
  ) async {
    var claimed = false;
    await tester.pumpWidget(
      _wrap(
        DailyLoginCalendarWidget(
          currentStreakDay: 2,
          claimedDaysInCycle: const {1, 2},
          canClaimToday: false,
          onClaim: () => claimed = true,
          cycleLength: 7,
        ),
      ),
    );

    // CommonButton renders its label via StrokeText (stroke+fill), so 2
    // Text matches — same convention used elsewhere in this kit's tests.
    await tester.tap(find.text('Claim').last);
    await tester.pump();
    expect(claimed, isFalse);
  });

  testWidgets("future days beyond currentStreakDay don't fire onClaim even if "
      'somehow tapped', (tester) async {
    var claimed = false;
    await tester.pumpWidget(
      _wrap(
        DailyLoginCalendarWidget(
          currentStreakDay: 2,
          claimedDaysInCycle: const {1, 2},
          canClaimToday: true,
          onClaim: () => claimed = true,
          cycleLength: 7,
        ),
      ),
    );

    // Highlight/tappable day is 3 (see above) — day 5 is a future, locked
    // slot with no tap handler at all.
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(claimed, isFalse);
  });

  // x-scale (m11) của ma trận — không dùng `getMaxScaleOnAxis()` (đã verify
  // qua debug script ở ENH-31/32 trong session này: trả sai giá trị cho ma
  // trận scale thuần), đọc trực tiếp phần tử ma trận thay thế. Mỗi
  // `_DaySlot` dùng cùng `Key('daySlotScale')` (hợp lệ vì mỗi instance nằm
  // dưới 1 parent khác nhau) nên cần `.at(index)` để chọn đúng ô ngày.
  double daySlotScaleAt(WidgetTester tester, int index) => tester
      .widgetList<Transform>(find.byKey(const Key('daySlotScale')))
      .elementAt(index)
      .transform
      .storage[0];

  testWidgets(
    'IDEA-23: mount với ngày đã claimed sẵn → không pop (scale = 1.0 ngay)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          DailyLoginCalendarWidget(
            currentStreakDay: 2,
            claimedDaysInCycle: const {1, 2},
            canClaimToday: true,
            onClaim: () {},
            cycleLength: 5,
          ),
        ),
      );

      // Day 1 và 2 đã claimed sẵn lúc mount — cả 2 phải ổn định = 1.0.
      expect(daySlotScaleAt(tester, 0), 1.0);
      expect(daySlotScaleAt(tester, 1), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-23: ngày vừa chuyển sang claimed → pop (scale bounce)',
    (tester) async {
      var claimedDays = <int>{1, 2};
      late StateSetter setDays;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setDays = setState;
              return DailyLoginCalendarWidget(
                currentStreakDay: 2,
                claimedDaysInCycle: claimedDays,
                canClaimToday: true,
                onClaim: () {},
                cycleLength: 5,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      setDays(() => claimedDays = {1, 2, 3});
      await tester.pump();

      // Day 3 (index 2) vừa chuyển sang claimed — giữa chừng pop, scale
      // khác 1.0. Day 1/2 (đã claimed từ trước) vẫn ổn định = 1.0.
      expect(daySlotScaleAt(tester, 0), 1.0);
      expect(daySlotScaleAt(tester, 1), 1.0);
      expect(daySlotScaleAt(tester, 2), isNot(1.0));

      await tester.pumpAndSettle();
      expect(daySlotScaleAt(tester, 2), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-23: Reduce Motion bật → không pop khi chuyển sang claimed',
    (tester) async {
      var claimedDays = <int>{1, 2};
      late StateSetter setDays;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                setDays = setState;
                return DailyLoginCalendarWidget(
                  currentStreakDay: 2,
                  claimedDaysInCycle: claimedDays,
                  canClaimToday: true,
                  onClaim: () {},
                  cycleLength: 5,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      setDays(() => claimedDays = {1, 2, 3});
      await tester.pump();

      expect(daySlotScaleAt(tester, 2), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-52: ô ngày hiện tại dùng PressableScale thay vì GestureDetector trần', () {
    testWidgets(
      'ô ngày hiện tại (tappable) bọc trong PressableScale, tap gọi đúng onClaim',
      (tester) async {
        var claimed = false;
        await tester.pumpWidget(
          _wrap(
            DailyLoginCalendarWidget(
              currentStreakDay: 3,
              claimedDaysInCycle: const {1, 2},
              canClaimToday: true,
              onClaim: () => claimed = true,
              cycleLength: 5,
            ),
          ),
        );

        // currentStreakDay=3, cycleLength=5 -> highlight day = 3 % 5 + 1 = 4
        // (cùng công thức đã dùng ở test "current day is highlighted..." có
        // sẵn trong file này). Chỉ check ancestor cụ thể của ô ngày 4, không
        // đếm tổng số PressableScale trong tree (CommonButton "Claim" cũng
        // tự dùng PressableScale riêng).
        expect(
          find.ancestor(
            of: find.text('4'),
            matching: find.byType(PressableScale),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('4'));
        await tester.pump();

        expect(claimed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ngày KHÔNG phải hiện tại → không có PressableScale ancestor (không tappable, giữ nguyên hành vi cũ)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            DailyLoginCalendarWidget(
              currentStreakDay: 3,
              claimedDaysInCycle: const {1, 2},
              canClaimToday: true,
              onClaim: () {},
              cycleLength: 5,
            ),
          ),
        );

        // currentStreakDay=3, cycleLength=5 -> highlight day = 4 (xem test
        // phía trên). Ngày 5 (chưa claim, không phải ngày hiện tại) không
        // tappable — không có PressableScale nào bọc nó.
        expect(
          find.ancestor(
            of: find.text('5'),
            matching: find.byType(PressableScale),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
