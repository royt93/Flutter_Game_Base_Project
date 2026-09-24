import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit_example/screens/cookbook_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// See `cookbook_screen_test.dart`'s header comment for why this is a
/// separate file. The 3 asset-loading tiles (`RemoteConfigService`/
/// `RemoteContentPack`/`AppVersionGateController`) live in their own
/// `cookbook_screen_remote_config_test.dart` instead — they were the ones
/// actually triggering the ticker-teardown issue once several other
/// tests preceded them (that file now sidesteps it entirely with a fake
/// `AssetBundle` instead of the real `rootBundle`); the rest below don't
/// do their own asset I/O and were stable in every arrangement tried.
///
/// `NeonBg` (used by [CookbookScreen]) runs a permanent `Ticker`, so
/// `pumpAndSettle()` never returns here — use a bounded `pump(duration)`
/// instead (see CLAUDE.md's testing note).
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

  testWidgets('CheckpointCoordinator tile checkpoints and restores a real value', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'CheckpointCoordinator — request + restore');

    expect(find.textContaining('restored='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets(
    'DisasterRecoverySaveExport tile builds, signs and previews a real export',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'DisasterRecoverySaveExport — build + sign + preview',
      );

      expect(find.textContaining('restore preview valid='), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets('OfflineProgressionService tile claims real idle earnings', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(
      tester,
      'OfflineProgressionService — claim idle earnings',
    );

    expect(find.textContaining('earned'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets(
    'PrestigeService tile: accumulate + prestige đúng thật, multiplier áp '
    'đúng vào OfflineProgressionService.claim() (FEAT-95)',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 1 lần: earn 100 coins < ngưỡng 100 nhưng >= (canPrestige dùng
      // >=) nên đủ prestige ngay lần đầu.
      await _tapAndShowToast(
        tester,
        'PrestigeService — accumulate + prestige + apply multiplier',
      );

      expect(find.textContaining('relics=1'), findsOneWidget);
      expect(find.textContaining('multiplier='), findsOneWidget);
      expect(find.textContaining('earned='), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets(
    'Consent-gated + sampled analytics tile forwards a real logged event',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'Consent-gated + sampled AnalyticsProvider stack',
      );

      expect(find.textContaining('forwarded='), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets('SdkEventSchemaRegistry tile validates a real event', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'SdkEventSchemaRegistry — validate');

    expect(find.textContaining('accepted='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('SdkHealthReport tile collects a real report', (tester) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'SdkHealthReport — collect');

    expect(find.textContaining('sections:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('DiagnosticsExportBundle tile builds and signs a real bundle', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'DiagnosticsExportBundle — build + sign');

    expect(find.textContaining('signed='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets(
    'CloudSaveProvider tile round-trips via the registered fake adapter',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'CloudSaveProvider (fake adapter) — round trip',
      );

      expect(find.textContaining('round-tripped:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets(
    'LeaderboardSyncSeam tile submits + fetches top via the registered fake '
    'adapter (FEAT-87)',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'LeaderboardSyncSeam (fake adapter) — submit + fetchTop',
      );

      // The fake adapter's `submitScore(boardId, score)` (no playerLabel
      // param, matching real Play Games/Game Center identifying the
      // signed-in player themselves) records under a fixed
      // 'remote_player' label — this proves the tile actually round-trips
      // through the SEAM, not the local fallback (which would show
      // 'CookbookPlayer' instead).
      expect(find.textContaining('top=remote_player:777'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets(
    'SecureStorageAdapter tile round-trips via the registered fake adapter',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'SecureStorageAdapter (fake adapter) — round trip',
      );

      expect(find.textContaining('read back:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets('maybeRequestReview tile evaluates a real happy-moment prompt', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(
      tester,
      'maybeRequestReview — happy-moment prompt',
    );

    expect(find.textContaining('triggered='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('AssetPreloadCoordinator tile preloads a real manifest', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(
      tester,
      'AssetPreloadCoordinator — preload manifest',
    );

    expect(find.textContaining('preload success='), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets('RoyLifecycleCoordinator tile registers a real hook', (
    tester,
  ) async {
    await _boot();
    await tester.pumpWidget(_wrap(const CookbookScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapAndShowToast(tester, 'RoyLifecycleCoordinator — registerHook');

    expect(find.textContaining('hook registered'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushToast(tester);
  });

  testWidgets(
    // ENH-91: BatterySaverCoordinator had no demo anywhere.
    'BatterySaverCoordinator tile forces tier low on low battery, releases '
    'on recovery',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'BatterySaverCoordinator — force PerformanceTier low on low '
        'battery, release on recovery',
      );

      expect(find.textContaining('tier=low'), findsOneWidget);
      expect(find.textContaining('isForcingLow=false'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets(
    // ENH-91: EconomyCertificate had no demo anywhere.
    'EconomyCertificate tile issues + verifies a real signed snapshot',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'EconomyCertificate — issue + verify a signed economy snapshot',
      );

      expect(find.textContaining('status=valid'), findsOneWidget);
      expect(find.textContaining('coins=50'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets(
    // ENH-91: ReproductionCapsule had no demo anywhere.
    'ReproductionCapsule tile captures + replays a real session, matches',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'ReproductionCapsule — capture a session, replay it, verify it '
        'matches',
      );

      expect(find.textContaining('replay matches=true'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );

  testWidgets(
    // ENH-91: ShadowActivationController had no demo anywhere.
    'ShadowActivationController tile auto-rolls-back a real guardrail '
    'violation',
    (tester) async {
      await _boot();
      await tester.pumpWidget(_wrap(const CookbookScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await _tapAndShowToast(
        tester,
        'ShadowActivationController — guardrail auto-rollback on '
        'violation',
      );

      expect(find.textContaining('killed: false -> true'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushToast(tester);
    },
  );
}
