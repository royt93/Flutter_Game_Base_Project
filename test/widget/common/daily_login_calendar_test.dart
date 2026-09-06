import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/daily_login_calendar.dart';

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
}
