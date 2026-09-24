import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/connectivity_coordinator.dart';
import 'package:roy_casual_kit/core/experiment_bucketing_service.dart';
import 'package:roy_casual_kit/core/kit_bootstrap.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';
import 'package:roy_casual_kit/core/remote_kill_switch_controller.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/debug_qa_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() async {
    Get.reset();
    await RoyCasualKit.resetForTesting();
  });

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

      // IDEA-58: the tab bar grew a row (8th tab added), pushing this
      // color-swatch row past the default 800x600 test viewport's bottom
      // edge — same "scroll it into view within its own
      // SingleChildScrollView first" fix as the Variant tab's own button
      // above.
      final colorFinder = find.byKey(
        Key('debugQaPlaygroundColor_${NeonTheme.magenta.toARGB32()}'),
      );
      await tester.ensureVisible(colorFinder);
      await tester.pump();
      await tester.tap(colorFinder);
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

  group('FEAT-93: Time Travel tab', () {
    tearDown(() => setDebugTimeOffsetMs(0));

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
      await tester.tap(find.text('Time Travel'));
      await tester.pump();
    }

    testWidgets('mặc định offset=0, hiện đúng "không time travel"', (
      tester,
    ) async {
      await openPanel(tester);

      expect(find.textContaining('không time travel'), findsOneWidget);
    });

    testWidgets(
      'bấm +24h -> offset cập nhật đúng, nowMsClamped() nhảy tới tương lai',
      (tester) async {
        await openPanel(tester);
        final before = DateTime.now().toUtc().millisecondsSinceEpoch;

        await tester.tap(find.byKey(const Key('debugQaTimeTravelPlus24h')));
        await tester.pump();

        expect(debugTimeOffsetMs, const Duration(hours: 24).inMilliseconds);
        final display = tester.widget<Text>(
          find.byKey(const Key('debugQaTimeTravelNow')),
        );
        final shown = int.parse(
          RegExp(r'nowMsClamped\(\): (\d+)').firstMatch(display.data!)!.group(1)!,
        );
        expect(
          shown,
          greaterThanOrEqualTo(before + const Duration(hours: 23).inMilliseconds),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bấm +2h rồi +7 ngày cộng dồn (không ghi đè)', (
      tester,
    ) async {
      await openPanel(tester);

      await tester.tap(find.byKey(const Key('debugQaTimeTravelPlus2h')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('debugQaTimeTravelPlus7d')));
      await tester.pump();

      expect(
        debugTimeOffsetMs,
        const Duration(hours: 2).inMilliseconds +
            const Duration(days: 7).inMilliseconds,
      );
    });

    testWidgets('bấm Reset -> offset về 0', (tester) async {
      await openPanel(tester);
      await tester.tap(find.byKey(const Key('debugQaTimeTravelPlus24h')));
      await tester.pump();
      expect(debugTimeOffsetMs, isNot(0));

      await tester.tap(find.byKey(const Key('debugQaTimeTravelReset')));
      await tester.pump();

      expect(debugTimeOffsetMs, 0);
      expect(find.textContaining('không time travel'), findsOneWidget);
    });
  });

  group('FEAT-93: Network Simulator tab', () {
    Future<ConnectivityCoordinator> openPanel(WidgetTester tester) async {
      final coordinator = ConnectivityCoordinator(
        signal: FakeConnectivitySignal(),
        probe: () async => true,
      );
      Get.put(coordinator, permanent: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();
      await tester.tap(find.text('Network'));
      await tester.pump();
      return coordinator;
    }

    testWidgets(
      'ConnectivityCoordinator chưa đăng ký -> báo rõ thay vì crash',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DebugQaOverlay(child: Material(child: Text('app content'))),
          ),
        );
        await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
        await tester.pump();
        await tester.tap(find.text('Network'));
        await tester.pump();

        expect(find.textContaining('chưa được đăng ký'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bấm Force offline -> state=offline ngay, không cần tắt mạng thật',
      (tester) async {
        final coordinator = await openPanel(tester);

        await tester.tap(find.byKey(const Key('debugQaNetworkForceOffline')));
        await tester.pump();

        expect(coordinator.state, ConnectivityState.offline);
        expect(find.textContaining('offline'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bấm Force degraded -> state=degraded ngay', (tester) async {
      final coordinator = await openPanel(tester);

      await tester.tap(find.byKey(const Key('debugQaNetworkForceDegraded')));
      await tester.pump();

      expect(coordinator.state, ConnectivityState.degraded);
    });

    testWidgets('bấm Clear (real) -> gỡ override, tự đánh giá lại', (
      tester,
    ) async {
      final coordinator = await openPanel(tester);
      await tester.tap(find.byKey(const Key('debugQaNetworkForceOffline')));
      await tester.pump();
      expect(coordinator.state, ConnectivityState.offline);

      await tester.tap(find.byKey(const Key('debugQaNetworkClear')));
      // debugForceState(null) re-evaluates connectivity through the SAME
      // real 400ms debounce Timer the coordinator normally uses (no fake
      // createTimer injected here — this test is about the DebugQaOverlay
      // wiring, not debounce internals, which connectivity_coordinator_test.dart
      // already covers in isolation) — pump past it so nothing is left
      // pending at teardown.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('FEAT-93: Variant Switcher tab', () {
    Future<ExperimentBucketingService> openPanel(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      Get.put(StorageService(await SharedPreferences.getInstance()));
      final service = ExperimentBucketingService();
      Get.put(service, permanent: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();
      await tester.tap(find.text('Variant'));
      await tester.pump();
      return service;
    }

    testWidgets(
      'ExperimentBucketingService chưa đăng ký -> báo rõ thay vì crash',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DebugQaOverlay(child: Material(child: Text('app content'))),
          ),
        );
        await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
        await tester.pump();
        await tester.tap(find.text('Variant'));
        await tester.pump();

        expect(find.textContaining('chưa được đăng ký'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'chọn 1 variant chip -> override có hiệu lực ở mọi lần gọi variantFor sau đó',
      (tester) async {
        final service = await openPanel(tester);

        await tester.tap(find.byKey(const Key('debugQaVariantChip_variant_a')));
        await tester.pump();

        expect(
          service.variantFor('demo_experiment', [
            'control',
            'variant_a',
            'variant_b',
          ]),
          'variant_a',
        );
        expect(
          find.textContaining('Đang chọn: variant_a'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('bấm Clear override -> quay lại bucket hash bình thường', (
      tester,
    ) async {
      final service = await openPanel(tester);
      await tester.tap(find.byKey(const Key('debugQaVariantChip_variant_a')));
      await tester.pump();

      // This tab's content (2 text fields + chip row + button) overflows
      // the panel's visible height at the default 800x600 test viewport —
      // scroll the button into view within its own SingleChildScrollView
      // before tapping it.
      await tester.ensureVisible(
        find.byKey(const Key('debugQaVariantClear')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('debugQaVariantClear')));
      await tester.pump();

      final normal = service.variantFor('demo_experiment', [
        'control',
        'variant_a',
        'variant_b',
      ]);
      expect(find.textContaining('Đang chọn: $normal'), findsOneWidget);
    });
  });

  group('IDEA-58: Kill Switch tab', () {
    Future<RemoteKillSwitchController> openPanel(
      WidgetTester tester, {
      Map<String, bool> assetDefaults = const {},
    }) async {
      SharedPreferences.setMockInitialValues({});
      Get.put(StorageService(await SharedPreferences.getInstance()));
      final controller = RemoteKillSwitchController(
        remoteConfig: RemoteConfigService(assetPath: 'assets/no_such_file.json'),
        assetDefaults: assetDefaults,
      );
      Get.put(controller, permanent: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();
      await tester.tap(find.text('Kill Switch'));
      await tester.pump();
      return controller;
    }

    testWidgets(
      'RemoteKillSwitchController chưa đăng ký -> báo rõ thay vì crash',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DebugQaOverlay(child: Material(child: Text('app content'))),
          ),
        );
        await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
        await tester.pump();
        await tester.tap(find.text('Kill Switch'));
        await tester.pump();

        expect(find.textContaining('chưa được đăng ký'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'hiện đúng danh sách feature flag từ assetDefaults ngay cả khi chưa query',
      (tester) async {
        await openPanel(
          tester,
          assetDefaults: {'shop_v2': false, 'winter_event': true},
        );

        expect(find.textContaining('shop_v2: enabled'), findsOneWidget);
        expect(find.textContaining('winter_event: KILLED'), findsOneWidget);
      },
    );

    testWidgets(
      'nhập feature id mới rồi bấm Thêm -> xuất hiện trong danh sách',
      (tester) async {
        await openPanel(tester);

        expect(find.textContaining('new_feature'), findsNothing);

        await tester.enterText(
          find.byKey(const Key('debugQaKillSwitchFeatureIdField')),
          'new_feature',
        );
        await tester.tap(find.byKey(const Key('debugQaKillSwitchAdd')));
        await tester.pump();

        expect(find.textContaining('new_feature: enabled'), findsOneWidget);
      },
    );

    testWidgets(
      'bấm Kill -> feature bị kill ngay, phản ánh đúng vào isKilled()',
      (tester) async {
        final controller = await openPanel(
          tester,
          assetDefaults: {'shop_v2': false},
        );

        expect(controller.isKilled('shop_v2'), isFalse);

        await tester.tap(find.byKey(const Key('debugQaKillSwitchKill_shop_v2')));
        await tester.pump();

        expect(controller.isKilled('shop_v2'), isTrue);
        expect(find.textContaining('shop_v2: KILLED'), findsOneWidget);
        expect(find.textContaining('localOverride'), findsOneWidget);
      },
    );

    testWidgets(
      'bấm Kill rồi Bỏ override -> quay lại đúng trạng thái asset default',
      (tester) async {
        final controller = await openPanel(
          tester,
          assetDefaults: {'shop_v2': false},
        );

        await tester.tap(find.byKey(const Key('debugQaKillSwitchKill_shop_v2')));
        await tester.pump();
        expect(controller.isKilled('shop_v2'), isTrue);

        await tester.tap(
          find.byKey(const Key('debugQaKillSwitchClear_shop_v2')),
        );
        await tester.pump();

        expect(controller.isKilled('shop_v2'), isFalse);
        expect(find.textContaining('shop_v2: enabled'), findsOneWidget);
      },
    );

    testWidgets(
      'feature bị kill bởi nguồn KHÔNG PHẢI local override -> không có nút bỏ, '
      'chỉ hiện ghi chú "không bật lại được qua đây"',
      (tester) async {
        await openPanel(
          tester,
          assetDefaults: {'always_off': true},
        );

        expect(find.textContaining('always_off: KILLED'), findsOneWidget);
        expect(
          find.byKey(const Key('debugQaKillSwitchClear_always_off')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('debugQaKillSwitchKill_always_off')),
          findsNothing,
        );
        expect(
          find.textContaining('không bật lại được qua đây'),
          findsOneWidget,
        );
      },
    );
  });

  group('IDEA-64: Boot tab', () {
    Future<void> openBootTab(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebugQaOverlay(child: Material(child: Text('app content'))),
        ),
      );
      await tester.longPress(find.byKey(const Key('debugQaOverlayTrigger')));
      await tester.pump();
      await tester.tap(find.text('Boot'));
      await tester.pump();
    }

    testWidgets(
      'chưa gọi RoyCasualKit.initialize() -> báo rõ, không crash',
      (tester) async {
        await openBootTab(tester);

        expect(
          find.textContaining('chưa được gọi trong app này'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'status healthy -> hiện rõ "OK" + đúng danh sách module đã đăng ký',
      (tester) async {
        await RoyCasualKit.initialize(
          config: const RoyCasualKitConfig(modules: {}),
        );

        await openBootTab(tester);

        expect(
          find.textContaining('OK — mọi module đăng ký thành công'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'có module đăng ký thành công -> liệt kê đúng tên module',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await RoyCasualKit.initialize(
          config: RoyCasualKitConfig(
            modules: {RoyCasualKitModule.storage},
            preferences: prefs,
          ),
        );

        await openBootTab(tester);

        expect(find.textContaining('✓ storage'), findsOneWidget);
      },
    );

    testWidgets(
      'status degraded -> hiện rõ "Degraded" + liệt kê đúng module lỗi',
      (tester) async {
        await RoyCasualKit.initialize(
          config: const RoyCasualKitConfig(
            modules: {RoyCasualKitModule.locale},
          ),
        );

        await openBootTab(tester);

        expect(find.textContaining('Degraded — 1 module lỗi'), findsOneWidget);
        expect(find.textContaining('✗ locale:'), findsOneWidget);
        expect(
          find.textContaining('OK — mọi module đăng ký thành công'),
          findsNothing,
        );
      },
    );
  });
}
