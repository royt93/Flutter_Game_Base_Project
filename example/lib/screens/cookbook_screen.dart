import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/roy_casual_kit.dart';

/// Live demo for every core service NOT already exercised by another
/// example screen (Settings/WidgetShowcase/GameDemo already cover
/// StorageService, LocaleService, AudioManager, NeonTheme, EconomyWallet,
/// RewardTransactionPipeline, PlayerProgressionService, InventoryService,
/// EnergyService, DailyLoginService, AchievementService,
/// LocalScoreboardService, PurchaseLedgerService, SaveSlotManager,
/// ConsentStateService, ExperimentBucketingService, OnboardingCoordinatorService,
/// PersistentCooldownService, ConnectivityCoordinator, DeepLinkCommandRouter,
/// AppSessionTracker, PlatformCapabilityRegistry, OfflineOutboxService,
/// ReminderService, CrashReporter, GameSessionController, and save_integrity
/// via `BackupRestorePanel`). Each tile below fires one real call and shows
/// its real result in a `ToastBanner` — not a mockup.
///
/// `tool/*_check.dart` CLI gates (Dev/CI tooling) and the pure formatting
/// helpers under `lib/core/utils/` (Utilities) have no in-app UI to demo —
/// see the README Cookbook section for those instead.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key, this.remoteContentBundle});

  /// Test-only seam: `RemoteConfigService` is registered via the usual
  /// `Get.put`/`.maybe` pattern below (a test can pre-register its own
  /// instance with a fake `AssetBundle` before pumping), but
  /// `RemoteContentPack` below isn't GetX-registered — this is its
  /// equivalent injection point, so a test never has to touch the real
  /// `rootBundle`.
  final AssetBundle? remoteContentBundle;

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late final RemoteConfigService _remoteConfig;
  late final RemoteContentPack<Map<String, Object?>> _seasonEventPack;
  late final RemoteKillSwitchController _killSwitch;
  late final AppVersionGateController _versionGate;
  late final SeasonEventService _seasonEvents;
  late final DailyQuestService _quests;
  late final CheckpointCoordinator _checkpoints;
  late final SdkEventSchemaRegistry _schemas;
  late final SdkHealthReport _health;
  late final DiagnosticsExportBundle _diagnostics;
  late final GameTimeController _gameTime;
  late final HapticChoreographer _haptics;
  late final AssetPreloadCoordinator _preloader;

  int _checkpointCounter = 0;

  @override
  void initState() {
    super.initState();
    _remoteConfig =
        RemoteConfigService.maybe ??
        Get.put(
          RemoteConfigService(
            assetPath: 'assets/remote_config/remote_config_defaults.json',
          ),
          permanent: true,
        );
    _seasonEventPack = RemoteContentPack<Map<String, Object?>>(
      assetPath: 'assets/remote_config/season_event_defaults.json',
      schemaVersion: 1,
      fromJson: (json) => json,
      bundle: widget.remoteContentBundle,
    );
    _killSwitch =
        RemoteKillSwitchController.maybe ??
        Get.put(
          RemoteKillSwitchController(remoteConfig: _remoteConfig),
          permanent: true,
        );
    _versionGate =
        AppVersionGateController.maybe ??
        Get.put(
          AppVersionGateController(remoteConfig: _remoteConfig),
          permanent: true,
        );
    _seasonEvents =
        SeasonEventService.maybe ??
        Get.put(SeasonEventService(), permanent: true);
    _quests = DailyQuestService.maybe ?? Get.put(DailyQuestService(), permanent: true);
    _checkpoints =
        CheckpointCoordinator.maybe ??
        Get.put(
          CheckpointCoordinator(storage: StorageService.to),
          permanent: true,
        );
    _checkpoints.registerParticipant(
      'cookbook_counter',
      snapshot: () => _checkpointCounter,
      restore: (data) => _checkpointCounter = data as int? ?? 0,
    );
    _schemas = SdkEventSchemaRegistry()
      ..register(
        EventSchema(
          name: 'cookbook_demo_event',
          version: 1,
          params: {
            'source': EventParamSchema(type: EventParamType.string, required: true),
          },
        ),
      );
    _health = SdkHealthReport()..registerAll(defaultHealthCollectors());
    _diagnostics = DiagnosticsExportBundle();
    _gameTime = GameTimeController();
    _haptics = HapticChoreographer();
    _preloader = AssetPreloadCoordinator(
      loader: (item) async => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    if (!Get.isRegistered<PurchaseSeam>()) {
      Get.put<PurchaseSeam>(FakePurchaseSeam(), permanent: true);
    }
    if (!Get.isRegistered<CloudSaveProvider>()) {
      Get.put<CloudSaveProvider>(FakeCloudSaveProvider(), permanent: true);
    }
    if (!Get.isRegistered<SecureStorageAdapter>()) {
      Get.put<SecureStorageAdapter>(FakeSecureStorageAdapter(), permanent: true);
    }
  }

  // BUG-64: `registerParticipant`'s `snapshot`/`restore` closures both
  // capture `this` (read/write `_checkpointCounter`). `_checkpoints` is a
  // `permanent: true` GetxService that outlives this screen — without
  // unregistering here, closing this screen for good (never reopened)
  // leaves those closures in `_checkpoints`' map forever, referencing a
  // disposed State: a real `requestCheckpoint()` call from anywhere else
  // in the app would keep invoking them, reading/writing a field on a
  // screen that isn't even shown.
  @override
  void dispose() {
    _checkpoints.removeParticipant('cookbook_counter');
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ToastBanner.show(context, message: message);
  }

  Future<void> _run(String label, FutureOr<String> Function() action) async {
    try {
      final result = await action();
      _toast('$label: $result');
    } catch (e) {
      _toast('$label failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'Cookbook', onBack: Get.back),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    _section('Storage & save data', [
                      _tile(
                        'VersionedJsonStore — save + load',
                        () async {
                          final store = VersionedJsonStore<Map<String, Object?>>(
                            storage: StorageService.to,
                            key: 'cookbook_versioned_demo',
                            schemaVersion: 1,
                            toJson: (m) => m,
                            fromJson: (j) => j,
                            migrate: (fromVersion, json) => json,
                          );
                          await store.save({'demo': DateTime.now().millisecondsSinceEpoch});
                          final loaded = store.load();
                          return 'round-tripped: $loaded';
                        },
                      ),
                      _tile(
                        'CheckpointCoordinator — request + restore',
                        () async {
                          _checkpointCounter++;
                          await _checkpoints.requestCheckpoint(critical: true);
                          final result = _checkpoints.restoreLatest();
                          return 'saved counter=$_checkpointCounter, restored=${result.value}';
                        },
                      ),
                      _tile(
                        'DisasterRecoverySaveExport — build + sign + preview',
                        () async {
                          final SaveSlotManager slots =
                              SaveSlotManager.maybe ?? Get.put<SaveSlotManager>(SaveSlotManager(), permanent: true);
                          final recovery = DisasterRecoverySaveExport(
                            storage: StorageService.to,
                            slotManager: slots,
                          );
                          final export = recovery.buildExport(
                            slotIds: slots.listSlots().map((s) => s.id).toList(),
                            appVersion: kAppVersion,
                          );
                          if (export case SdkFailure(:final message)) {
                            return 'buildExport failed: $message';
                          }
                          final signed = recovery.sign(export.value!, 'cookbook_demo_secret');
                          final preview = recovery.previewRestore(signed, 'cookbook_demo_secret');
                          return 'export ok, restore preview valid=${preview.isSuccess}';
                        },
                      ),
                    ]),
                    _section('Economy & progression', [
                      _tile(
                        'OfflineProgressionService — claim idle earnings',
                        () async {
                          final OfflineProgressionService offline = OfflineProgressionService.maybe ??
                              Get.put<OfflineProgressionService>(OfflineProgressionService(), permanent: true);
                          final earned = await offline.claim(0.5);
                          return 'earned ${earned.toStringAsFixed(2)} coins since last claim';
                        },
                      ),
                      _tile(
                        'DailyQuestService — register + progress + claim',
                        () {
                          const questId = 'cookbook_win_1';
                          if (!_quests.isCompleted(questId)) {
                            _quests.register(questId, 1);
                            _quests.incrementProgress(questId, 1);
                          }
                          final claimed = _quests.isCompleted(questId) && !_quests.isClaimed(questId)
                              ? _quests.claim(questId)
                              : false;
                          return 'progress=${_quests.progressOf(questId)}, claimed=$claimed';
                        },
                      ),
                      _tile(
                        'PurchaseSeam — buy via your adapter',
                        () async {
                          final seam = PurchaseSeam.maybe!;
                          final bought = await seam.buy('cookbook_demo_sku');
                          return 'bought=$bought, owns=${seam.isOwned('cookbook_demo_sku')}';
                        },
                      ),
                    ]),
                    _section('Live-ops & remote content', [
                      _tile(
                        'RemoteConfigService — init + read',
                        () async {
                          await _remoteConfig.init();
                          final multiplier = _remoteConfig.getDouble('reward_multiplier', fallback: 1.0);
                          return 'reward_multiplier=$multiplier (source: ${_remoteConfig.source.name})';
                        },
                      ),
                      _tile(
                        'RemoteContentPack — load asset + await refresh',
                        () async {
                          final content = await _seasonEventPack.load();
                          await _seasonEventPack.refreshed;
                          return 'loaded: $content';
                        },
                      ),
                      _tile(
                        'RemoteKillSwitchController — isKilled',
                        () {
                          final killed = _killSwitch.isKilled('cookbook_demo_feature');
                          return 'cookbook_demo_feature killed=$killed';
                        },
                      ),
                      _tile(
                        'SeasonEventService — currentWindow',
                        () {
                          final window = _seasonEvents.currentWindow(
                            'cookbook_demo_event',
                            length: const Duration(days: 7),
                            cooldown: const Duration(days: 21),
                          );
                          return 'active=${window.isActive}, ends=${window.end}';
                        },
                      ),
                    ]),
                    _section('Privacy, analytics & diagnostics', [
                      _tile(
                        'Consent-gated + sampled AnalyticsProvider stack',
                        () async {
                          final events = <String>[];
                          final sampler = PrivacyAwareAnalyticsSampler(
                            ConsentGatedAnalyticsProvider(_RecordingAnalyticsProvider(events)),
                            defaultSamplingRate: 1.0,
                          );
                          ConsentStateService.maybe?.grant(ConsentCategory.analytics);
                          sampler.logEvent('cookbook_demo_event', {'source': 'cookbook'});
                          return 'forwarded=${sampler.auditSnapshot.forwarded}, logged=$events';
                        },
                      ),
                      _tile(
                        'SdkEventSchemaRegistry — validate',
                        () {
                          final result = _schemas.validate('cookbook_demo_event', {'source': 'cookbook'});
                          return 'accepted=${result.accepted}, violations=${result.violations}';
                        },
                      ),
                      _tile(
                        'SdkHealthReport — collect',
                        () async {
                          final report = await _health.collect();
                          return 'sections: ${(report['sections'] as Map).keys.join(', ')}';
                        },
                      ),
                      _tile(
                        'DiagnosticsExportBundle — build + sign',
                        () async {
                          final bundle = await _diagnostics.build(appVersion: kAppVersion, health: _health);
                          final signed = _diagnostics.sign(bundle, 'cookbook_demo_secret');
                          return 'built, signed=${signed.containsKey(checksumKey)}, truncated=${bundle['truncated']}';
                        },
                      ),
                    ]),
                    _section('Platform seams', [
                      _tile(
                        'CloudSaveProvider (fake adapter) — round trip',
                        () async {
                          final provider = Get.find<CloudSaveProvider>();
                          await provider.signIn();
                          await provider.upload({'demo': true});
                          final downloaded = await provider.download();
                          return 'round-tripped: $downloaded';
                        },
                      ),
                      _tile(
                        'SecureStorageAdapter (fake adapter) — round trip',
                        () async {
                          await SecureStorage.write('cookbook_demo_key', 'demo_value');
                          final read = await SecureStorage.read('cookbook_demo_key');
                          return 'read back: ${read.value}';
                        },
                      ),
                      _tile(
                        'PluginAdapterConformanceSuite — verify PurchaseSeam',
                        () async {
                          final report = await PluginAdapterConformanceSuite.verifyPurchaseSeam(
                            PurchaseSeam.maybe!,
                            testProductId: 'cookbook_demo_sku',
                          );
                          return 'passed=${report.passed}${report.passed ? '' : ', failures=${report.failures}'}';
                        },
                      ),
                    ]),
                    _section('App/session infrastructure', [
                      _tile(
                        'AppVersionGateController — decisionFor',
                        () async {
                          await _remoteConfig.init();
                          final decision = _versionGate.decisionFor(kAppVersion);
                          return 'decision=${decision.name}';
                        },
                      ),
                      _tile(
                        'GameTimeController — tick',
                        () {
                          final steps = _gameTime.tick(0.016);
                          return 'tick(0.016s) -> $steps step(s), elapsed=${_gameTime.elapsed.value}';
                        },
                      ),
                      _tile(
                        'maybeRequestReview — happy-moment prompt',
                        () async {
                          var shown = false;
                          final triggered = await maybeRequestReview(
                            recentWinStreak: 3,
                            showReview: () async => shown = true,
                            minWinStreak: 3,
                          );
                          return 'triggered=$triggered, showReview called=$shown';
                        },
                      ),
                      _tile(
                        'MemoryWatchdog — track + orphans + release',
                        () {
                          final id = MemoryWatchdog.track(
                            WatchdogKind.subscription,
                            owner: 'CookbookScreen',
                            label: 'demoStream',
                          );
                          final orphans = MemoryWatchdog.orphans();
                          MemoryWatchdog.release(id);
                          return 'tracked id=$id, orphan count before release=${orphans.length}';
                        },
                      ),
                      _tile(
                        'AssetPreloadCoordinator — preload manifest',
                        () async {
                          final result = await _preloader.preload(const [
                            AssetManifestItem(id: 'demo_asset', kind: AssetKind.flutterAsset, path: 'assets/audio/'),
                          ]);
                          return 'preload success=${result.isSuccess}, progress=${_preloader.progress}';
                        },
                      ),
                      _tile(
                        'RoyLifecycleCoordinator — registerHook',
                        () {
                          RoyLifecycleCoordinator.maybe?.registerHook(
                            'cookbook_demo_hook',
                            (event) async => debugPrint('cookbook demo hook fired: $event'),
                          );
                          return 'hook registered (fires next background/resume)';
                        },
                      ),
                    ]),
                    _section('i18n, audio, haptics, theme', [
                      _tile(
                        'HapticChoreographer — play a prebuilt pattern',
                        () {
                          _haptics.play(HapticPattern.combo);
                          return 'played HapticPattern.combo';
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeonTheme.s16),
      child: PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NeonTheme.ink,
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            ...tiles,
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, FutureOr<String> Function() action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeonTheme.s8),
      child: CommonButton(
        label: label,
        variant: CommonButtonVariant.secondary,
        onTap: () => _run(label, action),
      ),
    );
  }
}

/// Records every event name it's asked to log — used to prove the
/// consent-gate + sampler stack actually forwards to the inner provider,
/// without pulling in a real analytics vendor.
class _RecordingAnalyticsProvider implements AnalyticsProvider {
  _RecordingAnalyticsProvider(this._events);
  final List<String> _events;

  @override
  void logEvent(String name, [Map<String, Object?>? params]) {
    _events.add(name);
  }
}
