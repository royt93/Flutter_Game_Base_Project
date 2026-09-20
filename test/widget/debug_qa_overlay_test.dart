import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
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

  group('IDEA-39: Playground tab', () {
    Future<void> openPanel(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      Get.put(StorageService(await SharedPreferences.getInstance()));

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();
    }

    testWidgets('mặc định mở ở tab State, chưa hiện CommonButton preview nào', (
      tester,
    ) async {
      await openPanel(tester);

      expect(find.text('State'), findsOneWidget);
      expect(find.text('Playground'), findsOneWidget);
      expect(find.byType(CommonButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'bấm tab Playground hiện đúng CommonButton preview với giá trị mặc định',
      (tester) async {
        await openPanel(tester);

        await tester.tap(find.text('Playground'));
        await tester.pump();

        expect(find.byType(CommonButton), findsOneWidget);
        expect(find.text('Preview'), findsWidgets);
        final button = tester.widget<CommonButton>(find.byType(CommonButton));
        expect(button.variant, CommonButtonVariant.primary);
        expect(button.color, NeonTheme.cyan);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('gõ vào ô Label cập nhật đúng label trên preview', (
      tester,
    ) async {
      await openPanel(tester);
      await tester.tap(find.text('Playground'));
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('debugQaPlaygroundLabelField')),
        'Buy now',
      );
      await tester.pump();

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.label, 'Buy now');
      expect(tester.takeException(), isNull);
    });

    testWidgets('chọn variant khác cập nhật đúng variant trên preview', (
      tester,
    ) async {
      await openPanel(tester);
      await tester.tap(find.text('Playground'));
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('debugQaPlaygroundVariant_danger')),
      );
      await tester.pump();

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.variant, CommonButtonVariant.danger);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chọn màu khác cập nhật đúng color trên preview', (
      tester,
    ) async {
      await openPanel(tester);
      await tester.tap(find.text('Playground'));
      await tester.pump();

      await tester.tap(
        find.byKey(
          Key('debugQaPlaygroundColor_${NeonTheme.magenta.toARGB32()}'),
        ),
      );
      await tester.pump();

      final button = tester.widget<CommonButton>(find.byType(CommonButton));
      expect(button.color, NeonTheme.magenta);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'quay lại tab State vẫn hiện đúng nội dung state dump như trước, không mất dữ liệu',
      (tester) async {
        await openPanel(tester);
        await tester.tap(find.text('Playground'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('debugQaPlaygroundLabelField')),
          'Custom',
        );
        await tester.pump();

        await tester.tap(find.text('State'));
        await tester.pump();

        expect(find.byType(CommonButton), findsNothing);
        expect(find.textContaining('Audio muted:'), findsOneWidget);

        // Quay lại Playground: giá trị đã gõ trước đó vẫn còn nguyên (state
        // được owner bởi DebugQaOverlay, không phải _Panel — không mất khi
        // đổi tab qua lại).
        await tester.tap(find.text('Playground'));
        await tester.pump();
        final button = tester.widget<CommonButton>(find.byType(CommonButton));
        expect(button.label, 'Custom');
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('IDEA-42: Replay tab', () {
    Future<void> openReplayTab(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      Get.put(StorageService(await SharedPreferences.getInstance()));
      Get.put(ReplayRecorder(), permanent: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();
      await tester.tap(find.text('Replay'));
      await tester.pump();
    }

    testWidgets(
      'ReplayRecorder chưa Get.put: tab Replay báo rõ thay vì crash',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        Get.put(StorageService(await SharedPreferences.getInstance()));
        // Cố ý KHÔNG Get.put ReplayRecorder.

        await tester.pumpWidget(
          const MaterialApp(
            home: DebugQaOverlay(child: Material(child: Text('app content'))),
          ),
        );
        await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
        await tester.pump();
        await tester.tap(find.text('Replay'));
        await tester.pump();

        expect(find.textContaining('chưa được đăng ký'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('mặc định: chưa ghi, 0 sự kiện, nút Stop/Export disabled', (
      tester,
    ) async {
      await openReplayTab(tester);

      expect(find.textContaining('Không ghi — 0 sự kiện'), findsOneWidget);
      final stopButton = tester.widget<CommonButton>(
        find.byKey(const Key('debugQaReplayStop')),
      );
      final exportButton = tester.widget<CommonButton>(
        find.byKey(const Key('debugQaReplayExport')),
      );
      expect(stopButton.onTap, isNull);
      expect(exportButton.onTap, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bấm Start: chuyển sang trạng thái đang ghi', (tester) async {
      await openReplayTab(tester);

      await tester.tap(find.byKey(const Key('debugQaReplayStart')));
      await tester.pump();

      expect(find.textContaining('Đang ghi'), findsOneWidget);
      expect(ReplayRecorder.maybe!.isRecording, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'bấm Start rồi record thủ công rồi Export: hiện đúng JSON chứa event vừa ghi',
      (tester) async {
        await openReplayTab(tester);

        await tester.tap(find.byKey(const Key('debugQaReplayStart')));
        await tester.pump();
        ReplayRecorder.maybe!.record('tap', {'x': 1});
        // Panel State.eventCount snapshot chỉ cập nhật qua auto-refresh
        // 500ms timer sẵn có của DebugQaOverlay (record() tự nó không gọi
        // setState) — chờ 1 tick timer để panel thấy đúng eventCount mới.
        await tester.pump(const Duration(milliseconds: 600));

        await tester.tap(find.byKey(const Key('debugQaReplayExport')));
        await tester.pump();

        final output = find.byKey(const Key('debugQaReplayExportOutput'));
        expect(output, findsOneWidget);
        final text = tester.widget<SelectableText>(output).data!;
        expect(text, contains('"type": "tap"'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bấm Stop: quay về trạng thái không ghi', (tester) async {
      await openReplayTab(tester);

      await tester.tap(find.byKey(const Key('debugQaReplayStart')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('debugQaReplayStop')));
      await tester.pump();

      expect(find.textContaining('Không ghi'), findsOneWidget);
      expect(ReplayRecorder.maybe!.isRecording, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-39: Health tab', () {
    testWidgets('bấm Generate report: hiện đúng JSON report', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();
      await tester.tap(find.text('Health'));
      await tester.pump();

      expect(find.byKey(const Key('debugQaHealthOutput')), findsNothing);

      await tester.tap(find.byKey(const Key('debugQaHealthGenerate')));
      await tester.pump();

      final output = tester.widget<SelectableText>(
        find.byKey(const Key('debugQaHealthOutput')),
      );
      expect(output.data, contains('schemaVersion'));
      expect(output.data, contains('"audio"'));
      expect(tester.takeException(), isNull);
    });
  });
}
