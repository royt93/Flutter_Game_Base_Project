import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('analytics ACK save failure retains event until retry', (
    tester,
  ) async {
    await app.app();
    await tester.pump(const Duration(seconds: 4));
    final entry = find.byKey(const ValueKey('analyticsAckSmokeEntry'));
    await tester.ensureVisible(entry);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    Future<void> tap(String key) async {
      final button = find.byKey(ValueKey(key));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tap('analyticsAckGrant');
    await tap('analyticsAckEnqueue');
    expect(find.text('Pending: 1 · Uploaded: 0'), findsOneWidget);
    await tap('analyticsAckFail');
    await tap('analyticsAckFlush');
    expect(
      find.text('ACK received; save failed, event retained for retry'),
      findsOneWidget,
    );
    expect(find.text('Pending: 1 · Uploaded: 0'), findsOneWidget);
    await tap('analyticsAckFlush');
    expect(find.text('Pending: 0 · Uploaded: 1'), findsOneWidget);
    expect(find.text('Flush saved; retry complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
