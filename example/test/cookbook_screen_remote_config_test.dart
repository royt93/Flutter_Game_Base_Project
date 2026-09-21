import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, CachingAssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit_example/screens/cookbook_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Separate file (see `cookbook_screen_test.dart`'s header comment for the
/// general reason) — for the 3 `CookbookScreen` tiles whose action does its
/// own async asset load (`RemoteConfigService.init()` /
/// `RemoteContentPack.load()` / `AppVersionGateController.decisionFor()`'s
/// own `_remoteConfig.init()`). Bisection found these 3 specifically
/// flaked under the full example test suite's concurrent isolates when
/// going through the real `rootBundle` — not a pump-timing issue, not
/// fixable by more/fewer pumps, not fixed by forcing `--concurrency=1`.
/// [_FakeAssetBundle] below sidesteps that at the root: it never touches
/// `rootBundle` at all, so the concurrency-sensitive path this bisected to
/// is simply not exercised here.
///
/// `NeonBg` (used by [CookbookScreen]) runs a permanent `Ticker`, so
/// `pumpAndSettle()` never returns here — use a bounded `pump(duration)`
/// instead (see CLAUDE.md's testing note).
class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);
  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final json = _assets[key];
    if (json == null) {
      throw FlutterError('_FakeAssetBundle: no fake asset registered for $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(json));
    return ByteData.view(bytes.buffer);
  }
}

const _remoteConfigAssetPath = 'assets/remote_config/remote_config_defaults.json';
const _seasonEventAssetPath = 'assets/remote_config/season_event_defaults.json';

AssetBundle _fakeBundle() => _FakeAssetBundle({
  _remoteConfigAssetPath: jsonEncode({
    'reward_multiplier': 1.5,
    'new_shop_ui_enabled': true,
  }),
  _seasonEventAssetPath: jsonEncode({
    'schemaVersion': 1,
    'eventName': 'Winter Festival',
    'bannerColor': '#7ED8FF',
  }),
});

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final store = StorageService(await SharedPreferences.getInstance());
  Get.put(store, permanent: true);
  Get.put(LocaleService(store), permanent: true);
}

Widget _wrap(Widget child) => GetMaterialApp(
  translations: AppTranslations(),
  locale: AppTranslations.fallback,
  fallbackLocale: AppTranslations.fallback,
  home: child,
);

Future<void> _scrollUntilVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 250, scrollable: find.byType(Scrollable).first);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapAndShowToast(WidgetTester tester, String label) async {
  final button = find.widgetWithText(CommonButton, label);
  await _scrollUntilVisible(tester, button);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _flushToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  tearDown(() => Get.reset());

  testWidgets('AppVersionGateController tile resolves a real decision', (
    tester,
  ) async {
    await _boot();
    Get.put(
      RemoteConfigService(assetPath: _remoteConfigAssetPath, bundle: _fakeBundle()),
      permanent: true,
    );
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'AppVersionGateController — decisionFor');

    expect(find.textContaining('decision='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('RemoteConfigService tile inits and reads a real asset value', (
    tester,
  ) async {
    await _boot();
    Get.put(
      RemoteConfigService(assetPath: _remoteConfigAssetPath, bundle: _fakeBundle()),
      permanent: true,
    );
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'RemoteConfigService — init + read');

    expect(find.textContaining('reward_multiplier=1.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('RemoteContentPack tile loads a real asset and awaits refresh', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(
      _wrap(CookbookScreen(remoteContentBundle: _fakeBundle())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(
      tester,
      'RemoteContentPack — load asset + await refresh',
    );

    expect(find.textContaining('loaded:'), findsOneWidget);
    expect(find.textContaining('Winter Festival'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });
}
