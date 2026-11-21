import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit_example/screens/analytics_ack_demo_screen.dart';

void main() {
  tearDown(Get.reset);

  testWidgets(
    'demo retains failed ACK then clears on retry without global storage',
    (tester) async {
      final storage = Get.put(StorageService(null));
      await storage.setString('sentinel', 'unchanged');
      final before = storage.exportAll();
      await tester.pumpWidget(
        const MaterialApp(home: AnalyticsAckDemoScreen()),
      );

      Future<void> tap(String key) async {
        final target = find.byKey(ValueKey(key));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
      }

      await tap('analyticsAckEnqueue');
      expect(find.text('Consent required'), findsOneWidget);
      expect(find.text('Pending: 0 · Uploaded: 0'), findsOneWidget);
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
      expect(find.text('Flush saved; retry complete'), findsOneWidget);
      expect(find.text('Pending: 0 · Uploaded: 1'), findsOneWidget);
      expect(storage.exportAll(), before);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(home: AnalyticsAckDemoScreen()),
      );
      expect(find.text('Pending: 0 · Uploaded: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
