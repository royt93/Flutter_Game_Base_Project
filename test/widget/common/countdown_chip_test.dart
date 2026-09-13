import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/presentation/widgets/common/countdown_chip.dart';

void main() {
  testWidgets('counts down every second, formatted via fmtDur', (tester) async {
    final target = DateTime.now().add(const Duration(seconds: 3));
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: CountdownChip(target: target)),
      ),
    );

    expect(find.text(fmtDur(const Duration(seconds: 3))), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(fmtDur(const Duration(seconds: 2))), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(fmtDur(const Duration(seconds: 1))), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('calls onDone exactly once on reaching zero, never again', (
    tester,
  ) async {
    var doneCount = 0;
    final target = DateTime.now().add(const Duration(seconds: 2));
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CountdownChip(target: target, onDone: () => doneCount++),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    expect(doneCount, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(doneCount, 1);
    expect(find.text(fmtDur(Duration.zero)), findsOneWidget);

    // Further ticks must not re-fire onDone (timer is cancelled once done).
    await tester.pump(const Duration(seconds: 3));
    expect(doneCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancels its timer on unmount (no leaked Timer, no throw)', (
    tester,
  ) async {
    final target = DateTime.now().add(const Duration(seconds: 5));
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: CountdownChip(target: target)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Unmount mid-countdown.
    await tester.pumpWidget(
      const MaterialApp(home: Material(child: SizedBox())),
    );

    // Advance time further: a leaked periodic Timer would either fail this
    // test at teardown ("A Timer is still pending") or throw via a
    // setState-after-dispose call.
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  group('BUG-30: đổi target lúc runtime (didUpdateWidget)', () {
    testWidgets(
      'target đổi giữa chừng trên CÙNG 1 instance → countdown nhận ngay '
      'giá trị mới, không tiếp tục đếm tới target cũ',
      (tester) async {
        var target = DateTime.now().add(const Duration(seconds: 10));
        late StateSetter setLocalState;

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setLocalState = setState;
                  return CountdownChip(target: target);
                },
              ),
            ),
          ),
        );

        expect(find.text(fmtDur(const Duration(seconds: 10))), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text(fmtDur(const Duration(seconds: 8))), findsOneWidget);

        // Người chơi mua "rút ngắn cooldown": target giảm còn 3 giây kể từ
        // bây giờ — vẫn cùng 1 CountdownChip instance (không đổi key).
        setLocalState(() {
          target = DateTime.now().add(const Duration(seconds: 3));
        });
        await tester.pump();

        expect(
          find.text(fmtDur(const Duration(seconds: 3))),
          findsOneWidget,
          reason:
              'phải nhận target mới ngay lập tức, không đợi rebuild toàn bộ',
        );

        await tester.pump(const Duration(seconds: 1));
        expect(find.text(fmtDur(const Duration(seconds: 2))), findsOneWidget);
      },
    );

    testWidgets(
      'đổi target xong rồi đếm về 0 → onDone gọi đúng 1 lần cho target MỚI '
      '(không bị bỏ sót, không gọi kép)',
      (tester) async {
        var doneCount = 0;
        var target = DateTime.now().add(const Duration(seconds: 10));
        late StateSetter setLocalState;

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setLocalState = setState;
                  return CountdownChip(
                    target: target,
                    onDone: () => doneCount++,
                  );
                },
              ),
            ),
          ),
        );

        setLocalState(() {
          target = DateTime.now().add(const Duration(seconds: 2));
        });
        await tester.pump();
        expect(doneCount, 0);

        await tester.pump(const Duration(seconds: 1));
        expect(doneCount, 0);
        await tester.pump(const Duration(seconds: 1));
        expect(doneCount, 1);

        // Không gọi kép nếu còn tick thừa sau đó.
        await tester.pump(const Duration(seconds: 3));
        expect(doneCount, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'đổi target thành 1 mốc đã ở QUÁ KHỨ (đã hết hạn) → onDone gọi ngay, '
      'không kẹt ở giá trị cũ',
      (tester) async {
        var doneCount = 0;
        var target = DateTime.now().add(const Duration(seconds: 10));
        late StateSetter setLocalState;

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setLocalState = setState;
                  return CountdownChip(
                    target: target,
                    onDone: () => doneCount++,
                  );
                },
              ),
            ),
          ),
        );

        setLocalState(() {
          target = DateTime.now().subtract(const Duration(seconds: 1));
        });
        await tester.pump();

        expect(find.text(fmtDur(Duration.zero)), findsOneWidget);
        expect(doneCount, 1);

        await tester.pump(const Duration(seconds: 2));
        expect(doneCount, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'setState của cha không đổi target → không reset/restart timer thừa',
      (tester) async {
        final target = DateTime.now().add(const Duration(seconds: 5));
        var unrelated = 0.0;
        late StateSetter setLocalState;

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setLocalState = setState;
                  return CountdownChip(
                    target: target,
                    fontSize: 14 + unrelated,
                  );
                },
              ),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 2));
        expect(find.text(fmtDur(const Duration(seconds: 3))), findsOneWidget);

        setLocalState(() => unrelated = 1);
        await tester.pump();

        // Cùng target → didUpdateWidget phải no-op, không nhảy lại về 5s.
        expect(find.text(fmtDur(const Duration(seconds: 3))), findsOneWidget);
      },
    );
  });

  group('ENH-37: Semantics', () {
    testWidgets(
      'label phản ánh đúng thời gian còn lại ở 2 mốc khác nhau, không phải liveRegion',
      (tester) async {
        final handle = tester.ensureSemantics();
        final target = DateTime.now().add(const Duration(seconds: 10));
        await tester.pumpWidget(
          MaterialApp(
            home: Material(child: CountdownChip(target: target)),
          ),
        );
        await tester.pump();

        var data = tester.getSemantics(find.byType(CountdownChip));
        expect(data.label, contains(fmtDur(const Duration(seconds: 10))));
        expect(data.getSemanticsData().flagsCollection.isLiveRegion, isFalse);

        await tester.pump(const Duration(seconds: 4));
        data = tester.getSemantics(find.byType(CountdownChip));
        expect(data.label, contains(fmtDur(const Duration(seconds: 6))));
        handle.dispose();
      },
    );

    testWidgets('semanticLabel tuỳ chỉnh ghi đè đúng label mặc định', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final target = DateTime.now().add(const Duration(seconds: 10));
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CountdownChip(
              target: target,
              semanticLabel: 'Sale ends soon',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(CountdownChip)).label,
        'Sale ends soon',
      );
      handle.dispose();
    });
  });
}
