import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/debug_qa_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('child always renders, closed panel shows nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DebugQaOverlay(child: Material(child: Text('app content'))),
      ),
    );

    expect(find.text('app content'), findsOneWidget);
    expect(find.byKey(const Key('debugQaOverlayTrigger')), findsOneWidget);
  });

  testWidgets(
    'long-press corner trigger opens the panel showing a StorageService key',
    (tester) async {
      SharedPreferences.setMockInitialValues({'demo_key': 42});
      Get.put(StorageService(await SharedPreferences.getInstance()));

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );

      expect(find.text('demo_key'), findsNothing);

      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();

      expect(find.text('demo_key'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      // Long-pressing again closes it.
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();

      expect(find.text('demo_key'), findsNothing);
    },
  );

  testWidgets(
    'IDEA-40: panel hiện đúng TrustedClock now + judgement khi StorageService đã đăng ký',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      Get.put(StorageService(await SharedPreferences.getInstance()));

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );

      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();

      expect(find.textContaining('TrustedClock now:'), findsOneWidget);
      expect(
        find.textContaining('TrustedClock now: not registered'),
        findsNothing,
      );
      // Lần sample đầu tiên chưa có gì để so sánh -> "n/a (first sample)".
      expect(
        find.text('TrustedClock judgement: n/a (first sample)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no StorageService/AudioManager/LocaleService registered -> opens without crashing',
    (tester) async {
      expect(Get.isRegistered<StorageService>(), isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );

      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('app content'), findsOneWidget);
    },
  );
}
