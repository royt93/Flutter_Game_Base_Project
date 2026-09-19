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
}
