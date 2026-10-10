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

  group('ENH-98: Continuous / Responsive CurrencyCounter', () {
    testWidgets('runtime validation throws on non-positive duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: CurrencyCounter(
              value: 100,
              duration: Duration.zero,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isA<ArgumentError>());
    });

    testWidgets(
      'continuous rolling starts from current intermediate value on mid-animation update',
      (tester) async {
        var value = 100;
        late StateSetter setValue;
        final key = GlobalKey<CurrencyCounterState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setValue = setState;
                  return CurrencyCounter(
                    key: key,
                    value: value,
                    compact: false,
                    duration: const Duration(milliseconds: 500),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(key.currentState!.displayedValue, 100);

        // Start animating from 100 to 200
        setValue(() => value = 200);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final intermediate = key.currentState!.displayedValue;
        expect(intermediate, greaterThan(100));
        expect(intermediate, lessThan(200));
        expect(key.currentState!.isAnimating, isTrue);

        // Interrupt mid-animation with target 300
        setValue(() => value = 300);
        await tester.pump();

        // The counter must start rolling from the intermediate value, NOT jump to 200 or 100
        expect(key.currentState!.displayedValue, intermediate);

        // Advance to completion
        await tester.pump(const Duration(milliseconds: 550));
        expect(key.currentState!.displayedValue, 300);
        expect(key.currentState!.isAnimating, isFalse);
        expect(find.text(fmtNum(300)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'chained reward updates advance smoothly without discontinuous drops',
      (tester) async {
        var value = 100;
        late StateSetter setValue;
        final key = GlobalKey<CurrencyCounterState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setValue = setState;
                  return CurrencyCounter(
                    key: key,
                    value: value,
                    compact: false,
                    duration: const Duration(milliseconds: 400),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        var lastSeen = 100;
        for (final target in [200, 350, 500, 800]) {
          setValue(() => value = target);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final current = key.currentState!.displayedValue;
          expect(current, greaterThanOrEqualTo(lastSeen));
          lastSeen = current;
        }

        await tester.pump(const Duration(milliseconds: 400));
        expect(key.currentState!.displayedValue, 800);
        expect(find.text(fmtNum(800)), findsOneWidget);
      },
    );

    testWidgets('tapping counter instantly triggers skipToEnd', (
      tester,
    ) async {
      var value = 100;
      late StateSetter setValue;
      final key = GlobalKey<CurrencyCounterState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setValue = setState;
                return CurrencyCounter(
                  key: key,
                  value: value,
                  compact: false,
                  duration: const Duration(milliseconds: 600),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      setValue(() => value = 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(key.currentState!.isAnimating, isTrue);
      expect(key.currentState!.displayedValue, lessThan(1000));

      // Tap on the counter
      await tester.tap(find.byType(CurrencyCounter));
      await tester.pump();

      expect(key.currentState!.displayedValue, 1000);
      expect(key.currentState!.isAnimating, isFalse);
      expect(find.text(fmtNum(1000)), findsOneWidget);
    });

    testWidgets('programmatic skipToEnd completes roll immediately', (
      tester,
    ) async {
      final key = GlobalKey<CurrencyCounterState>();
      var value = 50;
      late StateSetter setValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setValue = setState;
                return CurrencyCounter(
                  key: key,
                  value: value,
                  compact: false,
                  enableTapToSkip: false,
                  duration: const Duration(milliseconds: 500),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      setValue(() => value = 999);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      key.currentState!.skipToEnd();
      await tester.pump();

      expect(key.currentState!.displayedValue, 999);
      expect(key.currentState!.isAnimating, isFalse);
    });

    testWidgets(
      'reducedMotion turned on mid-animation immediately snaps to target',
      (tester) async {
        final key = GlobalKey<CurrencyCounterState>();
        var reduceMotion = false;
        var value = 10;
        late StateSetter update;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQueryData(disableAnimations: reduceMotion),
                child: MaterialApp(
                  home: Material(
                    child: CurrencyCounter(
                      key: key,
                      value: value,
                      compact: false,
                      duration: const Duration(milliseconds: 500),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pump();

        update(() => value = 500);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(key.currentState!.isAnimating, isTrue);

        update(() => reduceMotion = true);
        await tester.pump();

        expect(key.currentState!.displayedValue, 500);
        expect(key.currentState!.isAnimating, isFalse);
      },
    );
  });
}
