import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/presentation/widgets/common/cooldown_countdown_chip.dart';
import 'package:roy_casual_kit/presentation/widgets/common/countdown_chip.dart';

void main() {
  testWidgets(
    'remaining = Duration.zero: không hiện gì (ready, không có gì đếm)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: CooldownCountdownChip(remaining: Duration.zero),
          ),
        ),
      );

      expect(find.byType(CountdownChip), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'remaining > 0: render CountdownChip đúng giá trị ban đầu và đếm lùi',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: CooldownCountdownChip(remaining: Duration(seconds: 10)),
          ),
        ),
      );

      expect(find.text(fmtDur(const Duration(seconds: 10))), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text(fmtDur(const Duration(seconds: 7))), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onDone forward đúng xuống CountdownChip khi đếm về 0', (
    tester,
  ) async {
    var doneCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CooldownCountdownChip(
            remaining: const Duration(seconds: 2),
            onDone: () => doneCount++,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(doneCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cha rebuild với CÙNG remaining (vd Obx tick không đổi state): không reset lại timer',
    (tester) async {
      var unrelated = 0.0;
      late StateSetter setLocalState;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setLocalState = setState;
                return CooldownCountdownChip(
                  remaining: const Duration(seconds: 10),
                  fontSize: 14 + unrelated,
                );
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 3));
      expect(find.text(fmtDur(const Duration(seconds: 7))), findsOneWidget);

      setLocalState(() => unrelated = 1);
      await tester.pump();

      expect(
        find.text(fmtDur(const Duration(seconds: 7))),
        findsOneWidget,
        reason: 'remaining không đổi thì không được nhảy lại về 10s',
      );
    },
  );

  testWidgets(
    'service báo remaining mới hẳn (vd restart cooldown): nhận đúng target mới',
    (tester) async {
      var remaining = const Duration(seconds: 10);
      late StateSetter setLocalState;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setLocalState = setState;
                return CooldownCountdownChip(remaining: remaining);
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 4));
      expect(find.text(fmtDur(const Duration(seconds: 6))), findsOneWidget);

      setLocalState(() => remaining = const Duration(seconds: 20));
      await tester.pump();

      expect(
        find.text(fmtDur(const Duration(seconds: 20))),
        findsOneWidget,
        reason: 'remaining mới từ service phải cập nhật ngay, không cộng dồn',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
