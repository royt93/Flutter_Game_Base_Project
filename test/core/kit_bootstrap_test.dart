import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/kit_bootstrap.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/performance_tier_service.dart';
import 'package:roy_casual_kit/core/reminder_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/wake_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await RoyCasualKit.resetForTesting();
    Get.reset();
  });

  test('minimal bootstrap registers storage before locale', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final result = await RoyCasualKit.initialize(
      config: RoyCasualKitConfig(
        modules: {RoyCasualKitModule.storage, RoyCasualKitModule.locale},
        preferences: prefs,
      ),
    );

    expect(result.status, RoyCasualKitStatus.initialized);
    expect(result.registeredModules, {
      RoyCasualKitModule.storage,
      RoyCasualKitModule.locale,
    });
    expect(StorageService.maybe, isNotNull);
    expect(LocaleService.maybe, isNotNull);
  });

  test(
    'full bootstrap registers optional modules without platform init',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final modules = RoyCasualKitModule.values.toSet();
      final result = await RoyCasualKit.initialize(
        config: RoyCasualKitConfig(modules: modules, preferences: prefs),
      );

      expect(result.isDegraded, isFalse);
      expect(result.registeredModules, modules);
      expect(Get.isRegistered<AudioManager>(), isTrue);
      expect(Get.isRegistered<ReminderService>(), isTrue);
      expect(Get.isRegistered<PerformanceTierService>(), isTrue);
    },
  );

  test('concurrent and repeated initialize are idempotent', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = RoyCasualKitConfig(preferences: prefs);
    final results = await Future.wait([
      RoyCasualKit.initialize(config: config),
      RoyCasualKit.initialize(config: config),
    ]);

    expect(identical(results[0], results[1]), isTrue);
    expect(Get.find<StorageService>(), same(StorageService.maybe));
  });

  test('disabled modules stay unregistered', () async {
    final result = await RoyCasualKit.initialize(
      config: const RoyCasualKitConfig(modules: {}),
    );

    expect(result.registeredModules, isEmpty);
    expect(StorageService.maybe, isNull);
    expect(Get.isRegistered<AudioManager>(), isFalse);
  });

  test(
    // BUG-47: initialize() commits to "never throws" — a module whose
    // registration fails must land in `errors`/`degraded`, not crash boot.
    'locale without storage degrades instead of throwing (BUG-47)',
    () async {
      final result = await RoyCasualKit.initialize(
        config: const RoyCasualKitConfig(
          modules: {RoyCasualKitModule.locale},
        ),
      );

      expect(result.status, RoyCasualKitStatus.degraded);
      expect(result.errors, contains(RoyCasualKitModule.locale));
      expect(result.registeredModules, isEmpty);
      expect(StorageService.maybe, isNull);
      expect(LocaleService.maybe, isNull);
    },
  );

  test(
    'locale with storage still registers normally after BUG-47 fix',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final result = await RoyCasualKit.initialize(
        config: RoyCasualKitConfig(
          modules: {RoyCasualKitModule.storage, RoyCasualKitModule.locale},
          preferences: prefs,
        ),
      );

      expect(result.status, RoyCasualKitStatus.initialized);
      expect(LocaleService.maybe, isNotNull);
    },
  );

  test(
    // BUG-47: audio/wakeLock modules must restore persisted state via
    // init() during bootstrap, not stay on their hardcoded defaults.
    'audio and wakeLock modules restore persisted state during bootstrap (BUG-47)',
    () async {
      SharedPreferences.setMockInitialValues({
        'audio_muted': true,
        'wake_lock_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final result = await RoyCasualKit.initialize(
        config: RoyCasualKitConfig(
          modules: {
            RoyCasualKitModule.storage,
            RoyCasualKitModule.audio,
            RoyCasualKitModule.wakeLock,
          },
          preferences: prefs,
        ),
      );

      expect(result.isDegraded, isFalse);
      expect(Get.find<AudioManager>().muted.value, isTrue);
      expect(Get.find<WakeLockService>().enabled.value, isFalse);
    },
  );

  testWidgets('bootstrap result can be consumed by a widget', (tester) async {
    final result = await RoyCasualKit.initialize(
      config: const RoyCasualKitConfig(modules: {}),
    );
    await tester.pumpWidget(
      MaterialApp(home: Text(result.isDegraded ? 'degraded' : 'ready')),
    );
    expect(find.text('ready'), findsOneWidget);
  });
}
