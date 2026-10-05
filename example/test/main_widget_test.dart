import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';
import 'package:roy_casual_kit_example/main.dart' as app;
import 'package:roy_casual_kit_example/screens/home_screen.dart';

class _LifecycleAudio extends AudioManager {
  int pauses = 0;
  int resumes = 0;

  @override
  void pauseBgm() => pauses++;

  @override
  void resumeBgm() => resumes++;

  @override
  void onClose() {}
}

class _FlushStorage extends StorageService {
  _FlushStorage() : super(null);
  int flushes = 0;

  @override
  Future<void> flush() async {
    flushes++;
    await super.flush();
  }
}

void main() {
  setUp(() {
    NeonTheme.dark = false;
    NeonTheme.colorBlindSafe = false;
    Get.put<StorageService>(StorageService(null), permanent: true);
  });
  tearDown(() {
    NeonTheme.dark = false;
    NeonTheme.colorBlindSafe = false;
    Get.reset();
  });

  testWidgets(
    'app root renders HomeScreen with package font and switch theme',
    (tester) async {
      await tester.pumpWidget(
        const app.RoyBaseGameApp(initialLocale: Locale('en')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomeScreen), findsOneWidget);
      final theme = Theme.of(tester.element(find.byType(HomeScreen)));
      expect(theme.textTheme.bodyMedium!.fontFamily, NeonTheme.fontFamily);
      expect(theme.textTheme.bodyMedium!.fontFamilyFallback, ['sans-serif']);
      final switches = theme.switchTheme;
      expect(switches.trackColor!.resolve({}), isNotNull);
      expect(switches.trackOutlineColor!.resolve({}), isNotNull);
      expect(switches.thumbColor!.resolve({}), Colors.white);
      expect(switches.trackColor!.resolve({WidgetState.selected}), isNull);
      expect(
        switches.trackOutlineColor!.resolve({WidgetState.selected}),
        isNull,
      );
      expect(switches.thumbColor!.resolve({WidgetState.selected}), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'app root accepts Vietnamese locale and lifecycle pauses/resumes audio '
    'and flushes buffered storage',
    (tester) async {
      await Get.delete<StorageService>(force: true);
      final store =
          Get.put<StorageService>(_FlushStorage(), permanent: true)
              as _FlushStorage;
      final audio =
          Get.put<AudioManager>(_LifecycleAudio(), permanent: true)
              as _LifecycleAudio;

      await tester.pumpWidget(
        const app.RoyBaseGameApp(initialLocale: Locale('vi')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(Get.locale, const Locale('vi'));
      final root =
          tester.state(find.byType(app.RoyBaseGameApp))
              as WidgetsBindingObserver;

      await store.setIntBuffered('pending_counter', 42);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        root.didChangeAppLifecycleState(state);
        await tester.pump();
      }
      expect(audio.pauses, 4);
      expect(store.flushes, 4);
      expect(store.getInt('pending_counter'), 42);

      root.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(audio.resumes, 1);
      expect(store.flushes, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'app version loads package metadata once and keeps it on repeat',
    (tester) async {
      final oldVersion = kAppVersion;
      final oldBuild = kAppBuildNumber;
      final oldPackage = kPackageName;
      addTearDown(() {
        kAppVersion = oldVersion;
        kAppBuildNumber = oldBuild;
        kPackageName = oldPackage;
      });
      PackageInfo.setMockInitialValues(
        appName: 'Consumer',
        packageName: 'com.example.consumer',
        version: '1.2.3',
        buildNumber: '17',
        buildSignature: '',
      );

      await app.loadAppVersion();
      expect(kAppVersion, '1.2.3');
      expect(kAppBuildNumber, '17');
      expect(kPackageName, 'com.example.consumer');

      PackageInfo.setMockInitialValues(
        appName: 'Changed',
        packageName: 'com.example.changed',
        version: '9.9.9',
        buildNumber: '99',
        buildSignature: '',
      );
      await app.loadAppVersion();
      expect(kAppVersion, '1.2.3');
      expect(kAppBuildNumber, '17');
      expect(kPackageName, 'com.example.consumer');
    },
  );
}
