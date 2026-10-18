import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/offline_earnings_popup.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('OfflineEarningsPopup validation', () {
    test('rejects negative coins, elapsed, rate, or empty title/labels', () {
      expect(
        () => OfflineEarningsPopup(
          coins: -1,
          elapsed: Duration.zero,
          onCollect: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => OfflineEarningsPopup(
          coins: 10,
          elapsed: const Duration(seconds: -1),
          onCollect: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => OfflineEarningsPopup(
          coins: 10,
          elapsed: Duration.zero,
          ratePerSecond: -1,
          onCollect: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => OfflineEarningsPopup(
          coins: 10,
          elapsed: Duration.zero,
          ratePerSecond: double.infinity,
          onCollect: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => OfflineEarningsPopup(
          coins: 10,
          elapsed: Duration.zero,
          title: ' ',
          onCollect: () {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('OfflineEarningsPopup rendering and callbacks', () {
    testWidgets('renders count, elapsed time, rate, and Collect action', (
      tester,
    ) async {
      var collectCalls = 0;
      await tester.pumpWidget(
        _wrap(
          OfflineEarningsPopup(
            coins: 1250,
            elapsed: const Duration(hours: 4, minutes: 32),
            ratePerSecond: 0.25,
            onCollect: () => collectCalls++,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Welcome Back!'), findsNothing);
      expect(find.textContaining('4:32:00'), findsWidgets);
      expect(find.textContaining('0.25 coins/s'), findsOneWidget);
      expect(find.text('1,250'), findsWidgets);
      expect(
        find.byKey(const ValueKey('offlineEarningsCollectBtn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('offlineEarningsDoubleBtn')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('offlineEarningsCollectBtn')));
      expect(collectCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('count-up animates from zero and tap skips to end', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OfflineEarningsPopup(
            coins: 5000,
            elapsed: const Duration(hours: 2),
            onCollect: () {},
          ),
        ),
      );
      expect(find.text('0'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 250));
      final count = tester.widget<Text>(
        find.byKey(const ValueKey('offlineEarningsCoinCount')),
      );
      expect(count.data, isNot('5,000'));

      await tester.tap(find.byKey(const ValueKey('offlineEarningsCounterTap')));
      await tester.pump();
      expect(find.text('5,000'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'optional Double action invokes caller seam only when present',
      (tester) async {
        var doubleCalls = 0;
        await tester.pumpWidget(
          _wrap(
            OfflineEarningsPopup(
              coins: 100,
              elapsed: const Duration(minutes: 15),
              onCollect: () {},
              onDoubleTap: () => doubleCalls++,
            ),
          ),
        );

        final doubleButton = find.byKey(
          const ValueKey('offlineEarningsDoubleBtn'),
        );
        expect(doubleButton, findsOneWidget);
        await tester.tap(doubleButton);
        expect(doubleCalls, 1);
      },
    );

    testWidgets('Reduced Motion displays final amount immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          OfflineEarningsPopup(
            coins: 2500,
            elapsed: const Duration(days: 1, hours: 2),
            onCollect: () {},
          ),
          reduced: true,
        ),
      );

      expect(find.text('2,500'), findsWidgets);
      expect(find.textContaining('1d 2h'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Semantics announces title, coins and elapsed duration', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          OfflineEarningsPopup(
            coins: 300,
            elapsed: const Duration(hours: 3),
            semanticLabel: null,
            onCollect: () {},
          ),
          reduced: true,
        ),
      );

      final node = tester.getSemantics(
        find.byKey(const ValueKey('offlineEarningsSemantics')),
      );
      expect(node.label, contains('Welcome Back!'));
      expect(node.label, contains('300 coins'));
      expect(node.label, contains('03:00:00'));
      handle.dispose();
    });
  });

  testWidgets(
    'OfflineEarningsPopup.show presents overlay with caller actions',
    (tester) async {
      var collectCalls = 0;
      var doubleCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const ValueKey('openOfflinePopup'),
                onPressed: () => OfflineEarningsPopup.show(
                  context,
                  coins: 750,
                  elapsed: const Duration(hours: 2),
                  onCollect: () => collectCalls++,
                  onDoubleTap: () => doubleCalls++,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('openOfflinePopup')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Double 2x'), findsOneWidget);

      final collectButton = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Collect',
        ),
      );
      collectButton.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      expect(collectCalls, 1);

      // Reopen and exercise the optional double seam.
      await tester.tap(find.byKey(const ValueKey('openOfflinePopup')));
      await tester.pump(const Duration(milliseconds: 300));
      final doubleButton = tester.widget<NeonDialogButton>(
        find.byWidgetPredicate(
          (w) => w is NeonDialogButton && w.action.label == 'Double 2x',
        ),
      );
      doubleButton.action.onTap();
      await tester.pump(const Duration(milliseconds: 300));
      expect(doubleCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unmount during count-up disposes controller cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        OfflineEarningsPopup(
          coins: 100000,
          elapsed: const Duration(hours: 8),
          onCollect: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
