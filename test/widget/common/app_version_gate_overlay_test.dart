import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/app_version_gate.dart';
import 'package:roy_casual_kit/presentation/widgets/common/app_version_gate_overlay.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Material(child: child));

  testWidgets('decision ok: chỉ hiện child, không có overlay nào', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AppVersionGateOverlay(
          decision: GateDecision.ok,
          config: const AppVersionGateConfig(),
          launchStore: (_) async => true,
          child: const Text('app content'),
        ),
      ),
    );

    expect(find.text('app content'), findsOneWidget);
    expect(find.text('Update now'), findsNothing);
  });

  testWidgets('maintenance: hiện đúng message, không có nút update', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AppVersionGateOverlay(
          decision: GateDecision.maintenance,
          config: const AppVersionGateConfig(
            maintenanceMessage: 'Bảo trì tới 10h',
          ),
          launchStore: (_) async => true,
          child: const Text('app content'),
        ),
      ),
    );

    expect(find.text('Bảo trì tới 10h'), findsOneWidget);
    expect(find.text('Update now'), findsNothing);
  });

  testWidgets('maintenance: back KHÔNG dismiss được overlay', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppVersionGateOverlay(
          decision: GateDecision.maintenance,
          config: const AppVersionGateConfig(maintenanceMessage: 'x'),
          launchStore: (_) async => true,
          child: const Text('app content'),
        ),
      ),
    );

    final popScope = tester.widget<PopScope>(
      find.byKey(const Key('appVersionGatePopScope')),
    );
    expect(popScope.canPop, isFalse);
  });

  testWidgets('forceUpdate: bấm Update now gọi đúng launchStore với storeUrl', (
    tester,
  ) async {
    String? launchedUrl;
    await tester.pumpWidget(
      wrap(
        AppVersionGateOverlay(
          decision: GateDecision.forceUpdate,
          config: const AppVersionGateConfig(storeUrl: 'market://details'),
          launchStore: (url) async {
            launchedUrl = url;
            return true;
          },
          child: const Text('app content'),
        ),
      ),
    );

    await tester.tap(find.text('Update now').last);
    await tester.pump();

    expect(launchedUrl, 'market://details');
  });

  testWidgets(
    'forceUpdate: launchStore lỗi hiện recovery + nút Retry, không tự lặp',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        wrap(
          AppVersionGateOverlay(
            decision: GateDecision.forceUpdate,
            config: const AppVersionGateConfig(storeUrl: 'market://details'),
            launchStore: (_) async {
              attempts++;
              return false;
            },
            child: const Text('app content'),
          ),
        ),
      );

      await tester.tap(find.text('Update now').last);
      await tester.pump();

      expect(attempts, 1);
      expect(find.text('Retry'), findsWidgets);
      expect(find.textContaining('Không thể mở'), findsOneWidget);

      // Chưa bấm Retry -> không tự gọi lại thêm lần nào (không loop).
      expect(attempts, 1);

      await tester.tap(find.text('Retry').last);
      await tester.pump();

      expect(attempts, 2);
    },
  );

  testWidgets('softUpdate: bấm "Để sau" ẩn overlay và gọi onSoftDismiss', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      wrap(
        AppVersionGateOverlay(
          decision: GateDecision.softUpdate,
          config: const AppVersionGateConfig(),
          launchStore: (_) async => true,
          onSoftDismiss: () => dismissed = true,
          child: const Text('app content'),
        ),
      ),
    );

    expect(find.text('Để sau'), findsOneWidget);
    await tester.tap(find.text('Để sau').last);
    await tester.pump();

    expect(dismissed, isTrue);
    expect(find.text('Để sau'), findsNothing);
    expect(find.text('app content'), findsOneWidget);
  });

  testWidgets('soft back dismisses, decision change restores panel and clears launch error', (
    tester,
  ) async {
    var dismissals = 0;
    Future<void> render(GateDecision decision) => tester.pumpWidget(wrap(
      AppVersionGateOverlay(
        decision: decision,
        config: const AppVersionGateConfig(),
        launchStore: (_) async => false,
        onSoftDismiss: () => dismissals++,
        child: const Text('app content'),
      ),
    ));
    await render(GateDecision.softUpdate);
    var pop = tester.widget<PopScope>(find.byKey(const Key('appVersionGatePopScope')));
    pop.onPopInvokedWithResult!(false, null);
    await tester.pump();
    expect(dismissals, 1);
    expect(find.text('Update now'), findsNothing);

    await render(GateDecision.forceUpdate);
    expect(find.text('Update now'), findsWidgets);
    pop = tester.widget<PopScope>(find.byKey(const Key('appVersionGatePopScope')));
    pop.onPopInvokedWithResult!(false, null);
    await tester.pump();
    expect(dismissals, 1);
    expect(find.text('Update now'), findsWidgets);
    await tester.tap(find.text('Update now').last);
    await tester.pump();
    expect(find.text('Retry'), findsWidgets);

    await render(GateDecision.maintenance);
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('Không thể mở'), findsNothing);
    expect(find.text('Đang bảo trì'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('softUpdate: PopScope không chặn back (canPop true)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AppVersionGateOverlay(
          decision: GateDecision.softUpdate,
          config: const AppVersionGateConfig(),
          launchStore: (_) async => true,
          child: const Text('app content'),
        ),
      ),
    );

    final popScope = tester.widget<PopScope>(
      find.byKey(const Key('appVersionGatePopScope')),
    );
    expect(popScope.canPop, isTrue);
  });

  group('screen reader reach (BlockSemantics)', () {
    // `bySemanticsLabel` only matches nodes that are actually in the semantics
    // tree, so "findsNothing" means a screen reader cannot reach that label.
    Future<void> pumpGate(WidgetTester tester, GateDecision decision) =>
        tester.pumpWidget(
          wrap(
            AppVersionGateOverlay(
              decision: decision,
              config: const AppVersionGateConfig(storeUrl: 'https://x.test'),
              launchStore: (_) async => true,
              child: const Center(child: Text('BEHIND CONTENT')),
            ),
          ),
        );

    // A function, not a field: finders on semantics must be built after
    // `ensureSemantics()` has run inside the test, never at file load.
    Finder behind() => find.bySemanticsLabel('BEHIND CONTENT');

    testWidgets('force update hides the app behind it from screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGate(tester, GateDecision.forceUpdate);
      expect(find.bySemanticsLabel('Update now'), findsOneWidget);
      expect(behind(), findsNothing);
      handle.dispose();
    });

    testWidgets('maintenance hides the app behind it from screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGate(tester, GateDecision.maintenance);
      expect(find.bySemanticsLabel('Đang bảo trì'), findsOneWidget);
      expect(behind(), findsNothing);
      handle.dispose();
    });

    testWidgets('soft update also blocks reach while the dialog is up', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGate(tester, GateDecision.softUpdate);
      expect(find.bySemanticsLabel('Để sau'), findsOneWidget);
      expect(behind(), findsNothing);
      handle.dispose();
    });

    testWidgets('decision ok leaves the app fully reachable', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGate(tester, GateDecision.ok);
      expect(behind(), findsOneWidget);
      handle.dispose();
    });

    testWidgets('dismissing a soft update gives the app back to the reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGate(tester, GateDecision.softUpdate);
      expect(behind(), findsNothing);
      await tester.tap(find.text('Để sau'));
      await tester.pump();
      expect(behind(), findsOneWidget);
      handle.dispose();
    });
  });
}
