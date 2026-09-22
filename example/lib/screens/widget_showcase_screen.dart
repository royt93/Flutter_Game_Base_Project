import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/analytics_provider.dart';
import 'package:roy_casual_kit/core/app_info.dart';
import 'package:roy_casual_kit/core/app_session_tracker.dart';
import 'package:roy_casual_kit/core/app_version_gate.dart';
import 'package:roy_casual_kit/core/asset_preload_coordinator.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/core/offline_outbox_service.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';
import 'package:roy_casual_kit/core/connectivity_coordinator.dart';
import 'package:roy_casual_kit/core/consent_gated_analytics_provider.dart';
import 'package:roy_casual_kit/core/consent_state_service.dart';
import 'package:roy_casual_kit/core/daily_login_service.dart';
import 'package:roy_casual_kit/core/deep_link_command_router.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/experiment_bucketing_service.dart';
import 'package:roy_casual_kit/core/haptic_choreographer.dart';
import 'package:roy_casual_kit/core/haptics.dart';
import 'package:roy_casual_kit/core/local_scoreboard_service.dart';
import 'package:roy_casual_kit/core/onboarding_coordinator_service.dart';
import 'package:roy_casual_kit/core/persistent_cooldown_service.dart';
import 'package:roy_casual_kit/core/platform_capability_registry.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/save_slot_manager.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/utils/format.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/share_helper.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/core/utils/throttle.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_app_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_bg.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

/// Living demo of every widget in `lib/presentation/widgets/common/` — the
/// reference a future developer reads to see how each one is meant to be
/// used. Each section is a minimal, realistic call, not a stress test.
///
/// Dogfoods the kit's own [SectionHeader] (one per category) and [PanelCard]
/// (one per example) to lay itself out.
class WidgetShowcaseScreen extends StatefulWidget {
  const WidgetShowcaseScreen({super.key});

  @override
  State<WidgetShowcaseScreen> createState() => _WidgetShowcaseScreenState();
}

class _WidgetShowcaseScreenState extends State<WidgetShowcaseScreen> {
  // FEAT-45: sample gameplay migrated off unseeded dart:math Random() — a
  // fresh root seed per app session, 2 independent namespaced streams so
  // spinning the wheel never shifts the leaderboard demo's own sequence
  // (or vice versa).
  final _rng = SeededRandomService(DateTime.now().millisecondsSinceEpoch);

  bool _toggleOn = false;
  int _tabIndex = 0;
  int _coins = 100;
  int _mailBadgeCount = 12;
  final GlobalKey _coinCounterKey = GlobalKey();
  final GlobalKey _victoryCardKey = GlobalKey();
  int _plainTapCount = 0;
  int _throttledTapCount = 0;
  late final _throttledIncrement = throttled(
    () => setState(() => _throttledTapCount++),
  );
  int _starsEarned = 1;
  double _progress = 0.4;
  bool _showLoadingOverlay = false;
  // IDEA-53: demos CommonButton's loading state via a fake 1.5s async
  // action — the same shape a real "Buy"/save/cloud-sync button would use.
  bool _commonButtonLoading = false;

  // FEAT-51: demo counter — bumped once per successful hold-to-confirm,
  // proving onConfirm actually fired (not just that the widget renders).
  int _holdToConfirmCount = 0;

  Future<void> _simulateAsyncButton() async {
    setState(() => _commonButtonLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _commonButtonLoading = false);
  }

  // BackupRestorePanel demo: no real file/QR picker wired here — this just
  // simulates "export, then restore that same backup" round-tripping
  // through the panel's onExport/onImport seam.
  String? _lastBackup;

  // IDEA-41: HapticChoreographer demo — `_haptics` logs each pulse it
  // actually fires (not just "played") to `_hapticLog`, on-screen proof of
  // the pulse order/timing this task's device smoke test asserts.
  late final _haptics = HapticChoreographer(
    fire: (level) {
      fireHaptic(level);
      setState(() {
        final prefix = (_hapticLog?.isEmpty ?? true) ? '' : '${_hapticLog!} → ';
        _hapticLog = '$prefix${level.name}';
      });
    },
  );
  String? _hapticLog;

  void _playHaptic(HapticPattern pattern) {
    setState(() => _hapticLog = '');
    _haptics.play(pattern);
  }

  bool _rewardPopupOpen = false;
  bool _confettiActive = false;
  int _confettiTrigger = 0;
  final PageController _dotsPageController = PageController();
  int _dotsPageIndex = 0;
  late DateTime _countdownTarget = DateTime.now().add(
    const Duration(seconds: 15),
  );
  final _candyTextFieldController = TextEditingController();

  // FEAT-11: SpotlightOverlay demo — highlights the "Primary" CommonButton
  // from the Buttons & Interactive section above.
  final _spotlightTargetKey = GlobalKey();
  bool _spotlightActive = false;

  void _startTutorial() => setState(() => _spotlightActive = true);
  void _endTutorial() => setState(() => _spotlightActive = false);

  // IDEA-14: TutorialSequence demo — chains 2 existing spotlight targets
  // (the same Primary button as above, then the CurrencyCounter) into one
  // guided sequence instead of a single one-off SpotlightOverlay.
  final _tutorialSequenceController = TutorialSequenceController();

  void _startTutorialSequence() {
    _tutorialSequenceController.start([
      TutorialStep(
        targetKey: _spotlightTargetKey,
        title: 'Step 1 of 2',
        message: 'This is the Primary button — the main action on any screen.',
        color: NeonTheme.cyan,
      ),
      TutorialStep(
        targetKey: _coinCounterKey,
        title: 'Step 2 of 2',
        message: 'Your coin balance lives here — it updates live as you earn.',
        color: NeonTheme.gold,
      ),
    ]);
  }

  // IDEA-35: same 2-step tour, but authored as JSON instead of hardcoded
  // TutorialStep objects — this is what a designer editing
  // RemoteConfigService's `onboarding_flow_v1` string would produce.
  static const _jsonTutorialFlow = '''
  [
    {"id": "primary_button", "targetKey": "primary", "title": "Step 1 of 2",
     "message": "This is the Primary button (JSON-authored step)."},
    {"id": "coin_counter", "targetKey": "coins", "title": "Step 2 of 2",
     "message": "Your coin balance (JSON-authored step)."}
  ]
  ''';

  void _startTutorialSequenceFromJson() {
    _tutorialSequenceController.start(
      TutorialStep.listFromJson(
        _jsonTutorialFlow,
        keyRegistry: {'primary': _spotlightTargetKey, 'coins': _coinCounterKey},
      ),
    );
  }

  // IDEA-54: runs whichever flow OnboardingCoordinatorService says is next
  // (by priority: 'widget_kit_intro' first, then 'shop_tip') through the
  // ACTUAL TutorialSequence widget above — the coordinator itself never
  // touches TutorialSequenceController; this is the "caller" that does.
  // Marks the flow seen once TutorialSequenceController reports it's no
  // longer active, so a 2nd tap always advances to the next flow (or
  // shows nothing once both are seen) instead of repeating the same one.
  late final OnboardingCoordinatorService _onboarding;

  void _runNextOnboardingFlow() {
    final flowId = _onboarding.nextEligibleFlow();
    if (flowId == null) return;

    void onSequenceChanged() {
      if (!_tutorialSequenceController.isActive) {
        _tutorialSequenceController.removeListener(onSequenceChanged);
        _onboarding.markFlowSeen(flowId);
        if (mounted) setState(() {});
      }
    }

    _tutorialSequenceController.addListener(onSequenceChanged);
    if (flowId == 'widget_kit_intro') {
      _startTutorialSequence();
    } else {
      _startTutorialSequenceFromJson();
    }
  }

  // IDEA-56: demo state for SaveSlotManager — a per-slot "demo score" int
  // stored via `_saveSlots.keyFor(slotId, 'demo_score')`, proving 2 slots
  // never share data (each key is namespaced to its own slot id).
  late final SaveSlotManager _saveSlots;

  // IDEA-57: demo experiment key — the assigned variant is stable per
  // device (derived from `_experiments.anonymousId`), so this demo never
  // needs a "re-roll" control to prove the point.
  static const _demoExperimentKey = 'cta_color_test';
  static const _demoExperimentVariants = ['control', 'blue', 'gold'];
  late final ExperimentBucketingService _experiments;

  int _demoScoreFor(String slotId) =>
      StorageService.to.getInt(_saveSlots.keyFor(slotId, 'demo_score'));

  void _createSaveSlot() {
    final slot = _saveSlots.createSlot(
      'Player ${_saveSlots.listSlots().length + 1}',
    );
    unawaited(_saveSlots.setActiveSlot(slot.id));
    setState(() {});
  }

  void _setActiveSaveSlot(String id) {
    unawaited(_saveSlots.setActiveSlot(id));
    setState(() {});
  }

  void _addDemoScoreToActiveSlot() {
    final activeId = _saveSlots.activeSlotId;
    if (activeId == null) return;
    final key = _saveSlots.keyFor(activeId, 'demo_score');
    unawaited(
      StorageService.to.setInt(key, StorageService.to.getInt(key) + 10),
    );
    setState(() {});
  }

  Future<void> _deleteSaveSlot(String id, String displayName) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "$displayName"?',
      message:
          'This removes the slot and all of its data. This cannot be undone.',
      color: NeonTheme.red,
    );
    if (!confirmed) return;
    await _saveSlots.deleteSlot(id);
    if (mounted) setState(() {});
  }

  // IDEA-08: Game Feel demo state — SquashStretch tap count, a
  // ScreenShakeController the caller owns/disposes, and a cycling combo
  // heat value.
  int _squashTapCount = 0;
  final _screenShakeController = ScreenShakeController();
  double _comboHeat = 0.0;

  void _bumpSquashTapCount() => setState(() => _squashTapCount++);

  // IDEA-43: AchievementService.onUnlock demo — 3 taps unlocks
  // 'widget_kit_explorer', which AchievementUnlockListener (wrapping this
  // whole screen, see build()) turns into a ToastBanner automatically.
  int _achievementTaps = 0;

  void _bumpAchievementProgress() {
    if (_achievements.isCompleted('widget_kit_explorer')) return;
    _achievements.incrementProgress('widget_kit_explorer', 1);
    setState(() => _achievementTaps++);
  }

  // IDEA-44: QuestBoardPanel demo — a fixed 2-quest list this screen owns
  // locally (no DailyQuestService wiring here; the panel is deliberately
  // decoupled from any specific service, see the widget's own doc comment).
  var _questWinMatches = const QuestViewModel(
    id: 'win_3',
    label: 'Thắng 3 trận',
    progress: 2,
    target: 3,
    claimed: false,
  );
  var _questUseBooster = const QuestViewModel(
    id: 'use_booster',
    label: 'Dùng 1 booster',
    progress: 1,
    target: 1,
    claimed: false,
  );

  void _bumpQuestProgress() {
    setState(() {
      if (_questWinMatches.progress < _questWinMatches.target) {
        _questWinMatches = QuestViewModel(
          id: _questWinMatches.id,
          label: _questWinMatches.label,
          progress: _questWinMatches.progress + 1,
          target: _questWinMatches.target,
          claimed: _questWinMatches.claimed,
        );
      }
    });
  }

  // IDEA-45: audio ducking demo — mirrors AudioManager.duckCount on
  // screen (real device smoke-test evidence: a debug-print based check
  // turned out unobservable via logcat on this device/build, see the
  // task's own Quyết định for why this on-screen indicator is used
  // instead).
  int _duckDemoCount = 0;

  Future<void> _playDuckDemo() async {
    final manager = AudioManager.maybe;
    if (manager == null) return;
    final future = manager.playSfx('audio/demo_sfx.mp3', duck: true);
    setState(() => _duckDemoCount = manager.duckCount);
    await future;
    if (mounted) setState(() => _duckDemoCount = manager.duckCount);
  }

  void _claimQuest(String questId) {
    setState(() {
      if (questId == _questWinMatches.id) {
        _questWinMatches = QuestViewModel(
          id: _questWinMatches.id,
          label: _questWinMatches.label,
          progress: _questWinMatches.progress,
          target: _questWinMatches.target,
          claimed: true,
        );
      } else if (questId == _questUseBooster.id) {
        _questUseBooster = QuestViewModel(
          id: _questUseBooster.id,
          label: _questUseBooster.label,
          progress: _questUseBooster.progress,
          target: _questUseBooster.target,
          claimed: true,
        );
      }
    });
  }

  void _cycleComboHeat() => setState(
    () => _comboHeat = (_comboHeat + 0.25) > 1 ? 0 : _comboHeat + 0.25,
  );

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _dailyLogin =
        DailyLoginService.maybe ??
        Get.put(DailyLoginService(), permanent: true);
    _energy = EnergyService.maybe ?? Get.put(EnergyService(), permanent: true);
    _cooldown =
        PersistentCooldownService.maybe ??
        Get.put(PersistentCooldownService(), permanent: true);
    _consent =
        ConsentStateService.maybe ??
        Get.put(ConsentStateService(policyVersion: 1), permanent: true);
    _gatedAnalytics = ConsentGatedAnalyticsProvider(
      _DemoAnalyticsProvider(() => setState(() => _demoAnalyticsEventCount++)),
    );
    _connectivitySignal = FakeConnectivitySignal();
    _connectivity =
        ConnectivityCoordinator.maybe ??
        Get.put(
          ConnectivityCoordinator(
            signal: _connectivitySignal,
            probe: () async => _demoProbeSucceeds,
            debounceWindow: const Duration(milliseconds: 100),
            probeInterval: const Duration(seconds: 5),
          ),
          permanent: true,
        );
    _deepLinks =
        DeepLinkCommandRouter.maybe ??
              Get.put(
                DeepLinkCommandRouter(
                  routes: const [
                    DeepLinkRoute(
                      commandType: 'level',
                      scheme: 'roycasualkit',
                      host: 'open',
                      pathSegments: ['level', ':id'],
                    ),
                    DeepLinkRoute(
                      commandType: 'shop',
                      scheme: 'roycasualkit',
                      host: 'open',
                      pathSegments: ['shop'],
                    ),
                  ],
                ),
                permanent: true,
              )
          ..markReady();
    _deepLinks.registerHandler('level', _onLevelDeepLink);
    _deepLinks.registerHandler('shop', _onShopDeepLink);
    _versionGateRemoteConfig = RemoteConfigService(
      assetPath: 'assets/nonexistent_app_version_gate.json',
      fetchRemote: () async {
        switch (_versionGateScenario) {
          case 'soft':
            return {'appVersionRecommended': '9999.0.0'};
          case 'force':
            return {'appVersionMinimum': '9999.0.0'};
          case 'maintenance':
            return {
              'appVersionMaintenanceActive': true,
              'appVersionMaintenanceMessage':
                  'Đang bảo trì demo, quay lại sau nhé.',
            };
          default:
            return {};
        }
      },
    );
    _versionGate = AppVersionGateController(
      remoteConfig: _versionGateRemoteConfig,
    );
    _sessionTracker =
        AppSessionTracker.maybe ??
        Get.put(AppSessionTracker(), permanent: true);
    _platformCapabilities =
        PlatformCapabilityRegistry.maybe ??
        Get.put(PlatformCapabilityRegistry(), permanent: true);
    _assetPreload = AssetPreloadCoordinator(loader: _assetDemoLoader);
    _assetSession = GameSessionController();
    _sceneTransition = SceneTransitionController(
      coverDuration: const Duration(milliseconds: 260),
      revealDuration: const Duration(milliseconds: 220),
    );
    _progressionWallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    _progressionPipeline =
        RewardTransactionPipeline.maybe ??
        Get.put(
          RewardTransactionPipeline(wallet: _progressionWallet),
          permanent: true,
        );
    _progression =
        PlayerProgressionService.maybe ??
        Get.put(
          PlayerProgressionService(
            storage: StorageService.to,
            levelCurve: _progressionCurve,
            pipeline: _progressionPipeline,
          ),
          permanent: true,
        );
    _inventory =
        InventoryService.maybe ??
        Get.put(
          InventoryService(
            storage: StorageService.to,
            itemCatalog: _inventoryCatalog,
            capacity: 4,
          ),
          permanent: true,
        );
    _outbox =
        OfflineOutboxService.maybe ??
        Get.put(
          OfflineOutboxService(
            storage: StorageService.to,
            uploader: _outboxUploader,
            connectivity: _connectivity,
            conflictPolicy: ConflictPolicy.manual,
          ),
          permanent: true,
        );
    // IDEA-43: demo achievement — 3 taps to unlock, so AchievementUnlockToast
    // (via AchievementUnlockListener wrapping this screen below) has
    // something to show without waiting on real game progress.
    _achievements =
        AchievementService.maybe ??
        Get.put(AchievementService(), permanent: true);
    _achievements.register('widget_kit_explorer', 3);
    // IDEA-46: demo scoreboard — seed 2 rivals only on the very first boot
    // (an empty board) so relaunching the app doesn't keep re-adding
    // duplicate Alice/Charlie rows on top of whatever "You" has submitted
    // since.
    _scoreboard =
        LocalScoreboardService.maybe ??
        Get.put(LocalScoreboardService(), permanent: true);
    if (_scoreboard.topN(1).isEmpty) {
      _scoreboard.submitScore('Alice', 12340);
      _scoreboard.submitScore('Charlie', 8120);
    }
    _purchases =
        PurchaseLedgerService.maybe ??
        Get.put(PurchaseLedgerService(), permanent: true);
    // IDEA-54: 2 sample flows — 'widget_kit_intro' (the existing 2-step
    // TutorialSequence demo above) outranks 'shop_tip' (the JSON-authored
    // one), so the FIRST call to _runNextOnboardingFlow always starts the
    // intro, never the shop tip, until the intro is marked seen.
    _onboarding =
        OnboardingCoordinatorService.maybe ??
        Get.put(OnboardingCoordinatorService(), permanent: true);
    _onboarding.registerFlow('widget_kit_intro', priority: 10);
    _onboarding.registerFlow('shop_tip', priority: 0);
    _saveSlots =
        SaveSlotManager.maybe ?? Get.put(SaveSlotManager(), permanent: true);
    _experiments =
        ExperimentBucketingService.maybe ??
        Get.put(ExperimentBucketingService(), permanent: true);
  }

  // BUG-61: named methods (not inline closures) so dispose() can pass the
  // exact same function reference to unregisterHandler — DeepLinkCommandRouter
  // is a permanent singleton that outlives this screen, so a handler left
  // registered here would keep calling setState on this State forever after
  // it unmounts.
  void _onLevelDeepLink(DeepLinkCommand command) {
    if (!mounted) return;
    setState(
      () => _deepLinkLog = 'level: mở level ${command.params['id']}',
    );
  }

  void _onShopDeepLink(DeepLinkCommand command) {
    if (!mounted) return;
    setState(() => _deepLinkLog = 'shop: mở cửa hàng');
  }

  @override
  void dispose() {
    _deepLinks.unregisterHandler('level', _onLevelDeepLink);
    _deepLinks.unregisterHandler('shop', _onShopDeepLink);
    _dotsPageController.dispose();
    _screenShakeController.dispose();
    _tutorialSequenceController.dispose();
    _wheelController.dispose();
    _candyTextFieldController.dispose();
    _deepLinkController.dispose();
    _haptics.cancel();
    _assetSession.onClose();
    _sceneTransition.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  Future<SdkResult<void>> _sceneDemoLoad(
    void Function(double) onProgress,
  ) async {
    onProgress(0.4);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_sceneDemoForceFail) {
      return const SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Không tải được scene mới (demo lỗi giả lập).',
      );
    }
    onProgress(1.0);
    return const SdkSuccess(null);
  }

  // FEAT-47: manifest demo — 'atlas' phải load trước 'player_sprite'
  // (dependency), 'bg_music' là optional nên fail của nó không chặn scene.
  List<AssetManifestItem> get _assetDemoManifest => const [
    AssetManifestItem(
      id: 'atlas',
      kind: AssetKind.image,
      path: 'atlas.png',
      weight: 2,
    ),
    AssetManifestItem(
      id: 'player_sprite',
      kind: AssetKind.image,
      path: 'player_sprite.png',
      dependsOn: ['atlas'],
      weight: 2,
    ),
    AssetManifestItem(
      id: 'bg_music',
      kind: AssetKind.audio,
      path: 'bg_music.mp3',
      required: false,
      weight: 1,
    ),
  ];

  // Không có asset thật để load trong RoyGame template (xem roy_game.dart) —
  // loader giả lập độ trễ + 2 kịch bản lỗi chọn qua nút bấm demo, để chứng
  // minh hành vi required-fail-chặn-scene vs optional-fail-không-chặn.
  Future<void> _assetDemoLoader(AssetManifestItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (item.id == 'bg_music' && _assetDemoScenario == 'optionalFail') {
      throw Exception('demo: bg_music lỗi (optional, không chặn scene)');
    }
    if (item.id == 'atlas' && _assetDemoScenario == 'requiredFail') {
      throw Exception('demo: atlas lỗi (required, chặn scene)');
    }
  }

  Future<void> _grantProgressionXp(BuildContext context, int amount) async {
    // FEAT-54: collect every LevelUpEvent PlayerProgressionService.grantXp
    // fires (one per level crossed, in order) into a local buffer — the
    // demo's own responsibility, not LevelUpOverlayController's. The
    // overlay only ever receives already-crossed LevelUpEvents.
    final crossed = <LevelUpEvent>[];
    final sub = _progression.onLevelUp.listen((event) {
      if (event != null) crossed.add(event);
    });
    await _progression.grantXp(
      amount: amount,
      transactionId: 'demo_grant_${DateTime.now().microsecondsSinceEpoch}',
    );
    await sub.cancel();
    if (crossed.isNotEmpty) {
      unawaited(
        _levelUpController.show([
          for (final event in crossed) LevelUpCelebration(event: event),
        ]),
      );
    }
  }

  // FEAT-67: uploader giả lập — item có payload['forceConflict']==true luôn
  // báo conflict (mô phỏng server có giá trị khác), còn lại ack thành công.
  Future<SyncOutcome> _outboxUploader(
    Map<String, Object?> payload,
    String idempotencyKey,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (payload['forceConflict'] == true) {
      return const SyncConflict({
        'score': 999,
        'reason': 'server có giá trị khác',
      });
    }
    return const SyncAck();
  }

  Future<void> _inventoryGrant(String itemId, int quantity) async {
    final result = await _inventory.grant(
      lines: [InventoryLine(itemId: itemId, quantity: quantity)],
      transactionId: 'demo_grant_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted) return;
    setState(() {
      _inventoryStatus = result is SdkFailure<InventorySnapshot>
          ? 'Grant fail: ${result.message}'
          : 'Granted $quantity x $itemId';
    });
  }

  Future<void> _inventoryConsume(String itemId, int quantity) async {
    final result = await _inventory.consume(
      lines: [InventoryLine(itemId: itemId, quantity: quantity)],
      transactionId: 'demo_consume_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted) return;
    setState(() {
      _inventoryStatus = result is SdkFailure<InventorySnapshot>
          ? 'Consume fail: ${result.message}'
          : 'Consumed $quantity x $itemId';
    });
  }

  Future<void> _runAssetDemoPreload(String scenario) async {
    setState(() {
      _assetDemoScenario = scenario;
      _assetDemoStatus = 'Đang preload...';
    });
    final result = await _assetPreload.preload(_assetDemoManifest);
    if (!mounted) return;
    setState(() {
      if (result is SdkSuccess<void>) {
        _assetSession.markReady();
        _assetSession.start();
        _assetDemoStatus = 'Preload OK — scene sẵn sàng (phase: playing).';
      } else if (result is SdkFailure<void>) {
        _assetDemoStatus = 'Preload fail: ${result.message}';
      }
    });
  }

  // Sample world map: 3 completed (with stars), 1 unlocked, 4 locked —
  // LevelSelectGrid itself holds no progress state, this is what a real
  // save/progress system would hand in.
  final List<LevelState> _levelStates = const [
    LevelState.completed,
    LevelState.completed,
    LevelState.completed,
    LevelState.unlocked,
    LevelState.locked,
    LevelState.locked,
    LevelState.locked,
    LevelState.locked,
  ];
  final Map<int, int> _levelStars = const {1: 3, 2: 2, 3: 1};

  // FEAT-55: RewardChoicePanel demo — panel itself never grants anything,
  // this is where the "grant nằm trong RewardTransactionPipeline" callback
  // would actually call it in a real game; here just a toast.
  final List<RewardChoiceOption> _rewardChoices = const [
    RewardChoiceOption(
      id: 'coin_pack',
      label: 'Coin pack',
      icon: Icons.monetization_on,
      lines: [RewardLine(currency: 'coin', amount: 100)],
    ),
    RewardChoiceOption(
      id: 'gem_pack',
      label: 'Gem pack',
      icon: Icons.diamond,
      lines: [RewardLine(currency: 'gem', amount: 10)],
    ),
    RewardChoiceOption(
      id: 'skin',
      label: 'Exclusive skin',
      icon: Icons.palette,
      locked: true,
      lockedReason: 'Reach level 10',
    ),
  ];

  bool _networkConnected = true;
  bool _showShimmer = true;

  // DailyLoginCalendarWidget / EnergyBar demos wire to a real service
  // instance — self-registered here (permanent: true, like main.dart's own
  // singletons) if a host app hasn't already put one, so this section works
  // standalone in a widget test too. `StorageService(null)` is the same
  // safe in-memory fallback `storage_service.dart` already uses when
  // `SharedPreferences.getInstance()` fails at boot.
  late final DailyLoginService _dailyLogin;
  late final EnergyService _energy;
  late final PersistentCooldownService _cooldown;
  late final ConsentStateService _consent;
  late final FakeConnectivitySignal _connectivitySignal;
  late final ConnectivityCoordinator _connectivity;
  bool _demoProbeSucceeds = true;
  int _demoQueueRanCount = 0;
  late final ConsentGatedAnalyticsProvider _gatedAnalytics;
  int _demoAnalyticsEventCount = 0;
  late final DeepLinkCommandRouter _deepLinks;
  final _deepLinkController = TextEditingController(
    text: 'roycasualkit://open/level/5',
  );
  String _deepLinkLog = 'Chưa có deep link nào.';
  late RemoteConfigService _versionGateRemoteConfig;
  late AppVersionGateController _versionGate;
  String _versionGateScenario = 'ok';
  late final AppSessionTracker _sessionTracker;
  late final PlatformCapabilityRegistry _platformCapabilities;
  // FEAT-47: coordinator instance riêng cho demo, KHÔNG dùng chung với
  // GameDemoScreen's real Flame session — kịch bản lỗi ở đây cố tình giả
  // lập (không có asset thật để load trong template RoyGame), nên tách
  // biệt để không ảnh hưởng session thật của game demo.
  late final AssetPreloadCoordinator _assetPreload;
  late final GameSessionController _assetSession;
  String _assetDemoScenario = 'ok';
  String _assetDemoStatus = 'Chưa preload.';
  // FEAT-58: instance riêng, KHÔNG dùng chung _assetPreload/_assetSession ở
  // trên — 2 demo minh hoạ 2 khía cạnh khác nhau (preload thuần vs
  // transition state machine), dùng chung sẽ làm rối UX của cả 2.
  late final SceneTransitionController _sceneTransition;
  int _sceneRevision = 1;
  bool _sceneDemoForceFail = false;
  // FEAT-43: curve riêng cho demo — max level 3, level 3 mở khoá 50 gem qua
  // RewardTransactionPipeline thật (không giả lập).
  static const _progressionCurve = [
    LevelDefinition(level: 1, xpToNext: 100),
    LevelDefinition(level: 2, xpToNext: 200),
    LevelDefinition(
      level: 3,
      xpToNext: 0,
      unlockRewardLines: [RewardLine(currency: 'gem', amount: 50)],
    ),
  ];
  late final EconomyWallet _progressionWallet;
  late final RewardTransactionPipeline _progressionPipeline;
  late final PlayerProgressionService _progression;
  // FEAT-54: presents whatever LevelUpEvents _grantProgressionXp collected
  // from _progression.onLevelUp during its grantXp call — the overlay
  // never calls grantXp/pipeline.grant itself.
  final _levelUpController = LevelUpOverlayController();
  // FEAT-44: catalog riêng cho demo — potion stack tới 10, sword không
  // stack nhưng equip được.
  static const _inventoryCatalog = {
    'potion': ItemDefinition(id: 'potion', maxStack: 10),
    'sword': ItemDefinition(
      id: 'sword',
      equippable: true,
      rarity: ItemRarity.rare,
    ),
  };
  late final InventoryService _inventory;
  String _inventoryStatus = '';
  // FEAT-56: InventoryGrid demo's own selection — the grid never tracks
  // this itself (see class doc), a caller re-passes it after onSlotTap.
  int? _selectedInventorySlotId;
  late final OfflineOutboxService _outbox;
  int _outboxCounter = 0;
  late final AchievementService _achievements;
  late final LocalScoreboardService _scoreboard;
  // IDEA-48: toggles the demo between topN(3) (always the leaders) and
  // entriesAround('You', radius: 1) (the classic "you're #N" window) — the
  // 2 API are genuinely different results once 'You' isn't in the top 3.
  bool _showRankAround = false;

  // FEAT-52: toggles AdaptiveGameHud's debugShowBounds demo control.
  bool _hudDebugBounds = false;

  void _submitRandomScore() {
    final score = 1000 + _rng.stream('leaderboard_demo').nextInt(15000);
    ReplayRecorder.maybe?.record('leaderboard_submit', {
      'expectedOutcome': score,
    });
    setState(() => _scoreboard.submitScore('You', score));
  }

  void _claimDailyLogin() => setState(() => _dailyLogin.claimToday());

  void _consumeEnergy() => setState(() => _energy.consumeEnergy());

  // IDEA-13: WheelSpinner demo — the wheel never picks its own result, so
  // the demo's own RNG decides which index to spin to.
  static final _wheelSegments = [
    WheelSegment(label: '10', color: NeonTheme.cyan),
    WheelSegment(label: '50', color: NeonTheme.magenta),
    WheelSegment(label: '100', color: NeonTheme.lime),
    WheelSegment(label: 'Jackpot', color: NeonTheme.gold),
    WheelSegment(label: '20', color: NeonTheme.purple),
    WheelSegment(label: '5', color: NeonTheme.red),
  ];
  final _wheelController = WheelSpinnerController();

  void _spinWheel() {
    final segment = _rng.stream('wheel_spin').nextInt(_wheelSegments.length);
    // IDEA-42: recorded (no-op if ReplayRecorder.start() was never called)
    // so a QA session capturing this demo can later replay the exact same
    // spins via `replayCapsule` — 'expectedOutcome' is that helper's own
    // divergence-check convention.
    ReplayRecorder.maybe?.record('wheel_spin', {'expectedOutcome': segment});
    _wheelController.spin(segment);
  }

  void _bumpCoins() => setState(() => _coins += 25);

  // FEAT-12: fly 5 coins from the button toward the CurrencyCounter's
  // GlobalKey, bumping the displayed value by 5 (25 ~/ 5) per arrival so
  // the running total lands on +25 once the last coin lands.
  void _flyCoins() {
    const totalAmount = 25;
    const coinCount = 5;
    final size = MediaQuery.of(context).size;
    CoinFlyOverlay.show(
      context,
      from: Offset(size.width / 2, size.height - 80),
      targetKey: _coinCounterKey,
      coinCount: coinCount,
      onArrive: () {
        if (mounted) setState(() => _coins += totalAmount ~/ coinCount);
      },
    );
  }

  // FEAT-21: fire several in quick succession — the "spam" test the task
  // asks for. Each self-cleans via FloatingComboText.show, no state to
  // track here.
  void _spamComboText() {
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 90), () {
        if (!mounted) return;
        FloatingComboText.show(
          context,
          text: '+${(i + 1) * 10}',
          color: NeonTheme.gold,
        );
      });
    }
  }

  void _cycleStars() => setState(() => _starsEarned = (_starsEarned + 1) % 4);

  void _bumpProgress() =>
      setState(() => _progress = (_progress + 0.2) > 1 ? 0 : _progress + 0.2);

  void _flashLoadingOverlay() {
    setState(() => _showLoadingOverlay = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showLoadingOverlay = false);
    });
  }

  Future<void> _runConfirmDialog() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete save?',
      message: 'This cannot be undone.',
      confirmLabel: 'ok'.tr,
      cancelLabel: 'cancel'.tr,
      color: NeonTheme.red,
      icon: Icons.delete_outline_rounded,
    );
    if (!mounted) return;
    ToastBanner.show(
      context,
      message: confirmed ? 'Confirmed' : 'Cancelled',
      color: confirmed ? NeonTheme.lime : NeonTheme.muted,
    );
  }

  Future<void> _runBottomSheet() {
    return showCommonBottomSheet<void>(
      context,
      color: NeonTheme.cyan,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: NeonTheme.s16),
          CommonListTile(
            title: 'Restart level',
            leading: Icon(Icons.replay_rounded, color: NeonTheme.cyan),
            onTap: Get.back,
          ),
          const SizedBox(height: NeonTheme.s8),
          CommonListTile(
            title: 'Share score',
            leading: Icon(Icons.share_rounded, color: NeonTheme.magenta),
            onTap: Get.back,
          ),
        ],
      ),
    );
  }

  // IDEA-06: proves the VictoryCardTemplate -> RepaintBoundary ->
  // shareScoreCard wiring described in that widget's doc comment actually
  // works end-to-end, not just that the card renders.
  Future<void> _shareVictoryCard() {
    return shareScoreCard(
      boundaryKey: _victoryCardKey,
      levelText: 'Level 50 Complete!',
      sharePositionContext: context,
    );
  }

  void _showBoughtToast() {
    ToastBanner.show(context, message: 'Purchased!', color: NeonTheme.lime);
  }

  // IDEA-47: ShopItemCard demo — simulates "IAP already verified by the
  // store/server" (no real in_app_purchase backend here) then calls
  // straight into PurchaseLedgerService, same as a real PurchaseSeam
  // adapter would after a real receipt check.
  late final PurchaseLedgerService _purchases;

  static const _removeAdsSku = 'remove_ads';
  static const _gemsSku = 'gems';

  void _buyGems(int amount) {
    setState(() => _purchases.grantConsumable(_gemsSku, amount));
    _showBoughtToast();
  }

  void _buyRemoveAds() {
    setState(() => _purchases.grantPermanent(_removeAdsSku));
    _showBoughtToast();
  }

  void _openRewardPopup() => setState(() => _rewardPopupOpen = true);

  void _closeRewardPopup() => setState(() => _rewardPopupOpen = false);

  void _fireConfetti() {
    setState(() {
      _confettiTrigger++;
      _confettiActive = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // IDEA-43: any achievement unlock anywhere on this screen (see the
    // "Achievements" demo card below) shows a ToastBanner via
    // AchievementUnlockListener — reuses the existing toast, no new overlay
    // plumbing.
    // FEAT-54: wraps the whole screen, same "overlay everything" pattern
    // as PauseOverlay/NeonDialog.overlay — works over any content
    // (including, in a real game, a full-screen Flame GameWidget).
    return LevelUpOverlay(
      controller: _levelUpController,
      onSkipTap: _levelUpController.skip,
      child: AchievementUnlockListener(
        child: Scaffold(
          body: Stack(
            children: [
              NeonBg(
                child: SafeArea(
                  child: Column(
                    children: [
                      NeonAppBar(title: 'Widget Kit', color: NeonTheme.magenta),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(NeonTheme.s16),
                          children: [
                            const SectionHeader(title: 'Buttons & Interactive'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'CommonButton',
                              child: Wrap(
                                spacing: NeonTheme.s16,
                                runSpacing: NeonTheme.s16,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  CommonButton(
                                    key: _spotlightTargetKey,
                                    label: 'Primary',
                                    width: 140,
                                    onTap: () {},
                                  ),
                                  CommonButton(
                                    label: 'Secondary',
                                    width: 140,
                                    variant: CommonButtonVariant.secondary,
                                    onTap: () {},
                                  ),
                                  CommonButton(
                                    label: 'Danger',
                                    width: 140,
                                    variant: CommonButtonVariant.danger,
                                    onTap: () {},
                                  ),
                                  CommonButton(
                                    icon: Icons.settings_rounded,
                                    variant: CommonButtonVariant.icon,
                                    onTap: () {},
                                  ),
                                  // IDEA-53: loading state — blocks re-tap and
                                  // shows a spinner for a fake 1.5s async call.
                                  CommonButton(
                                    label: 'Simulate async',
                                    width: 180,
                                    loading: _commonButtonLoading,
                                    onTap: _simulateAsyncButton,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'AsyncCommonButton',
                              child: Wrap(
                                spacing: NeonTheme.s16,
                                runSpacing: NeonTheme.s16,
                                children: [
                                  // FEAT-50: self-managed loading→success, no
                                  // manual bool needed like the demo above.
                                  AsyncCommonButton(
                                    label: 'Save',
                                    width: 160,
                                    onPressed: () => Future<void>.delayed(
                                      const Duration(milliseconds: 1200),
                                    ),
                                  ),
                                  AsyncCommonButton(
                                    label: 'Fails',
                                    width: 160,
                                    variant: CommonButtonVariant.danger,
                                    onPressed: () => Future<void>.delayed(
                                      const Duration(milliseconds: 800),
                                      () => throw Exception('demo error'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'CandyToggleSwitch',
                              child: Row(
                                children: [
                                  CandyToggleSwitch(
                                    value: _toggleOn,
                                    onChanged: (v) =>
                                        setState(() => _toggleOn = v),
                                  ),
                                  const SizedBox(width: NeonTheme.s16),
                                  Text(_toggleOn ? 'On' : 'Off'),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'HoldToConfirmButton',
                              child: Wrap(
                                spacing: NeonTheme.s16,
                                runSpacing: NeonTheme.s16,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  HoldToConfirmButton(
                                    label: 'Delete',
                                    onConfirm: () =>
                                        setState(() => _holdToConfirmCount++),
                                  ),
                                  HoldToConfirmButton(
                                    label: 'Reset',
                                    shape: HoldToConfirmShape.linear,
                                    width: 180,
                                    onConfirm: () =>
                                        setState(() => _holdToConfirmCount++),
                                  ),
                                  Text('Confirmed: $_holdToConfirmCount'),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'SegmentedTabBar',
                              child: SegmentedTabBar(
                                labels: const ['Easy', 'Normal', 'Hard'],
                                selectedIndex: _tabIndex,
                                onChanged: (i) => setState(() => _tabIndex = i),
                              ),
                            ),
                            _Demo(
                              label: 'IconBadgeButton',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconBadgeButton(
                                    icon: Icons.notifications_rounded,
                                    semanticLabel: 'Notifications',
                                    showBadge: true,
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: NeonTheme.s24),
                                  IconBadgeButton(
                                    icon: Icons.mail_rounded,
                                    semanticLabel: 'Mail',
                                    badgeCount: _mailBadgeCount,
                                    onTap: () =>
                                        setState(() => _mailBadgeCount++),
                                  ),
                                ],
                              ),
                            ),
                            // Hidden if AudioManager isn't registered — the
                            // example app always registers it (see main.dart),
                            // so it renders here.
                            const _Demo(
                              label: 'SoundToggleFab',
                              child: SoundToggleFab(),
                            ),
                            _Demo(
                              label: 'AudioManager audio ducking (IDEA-45)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Bấm để phát 1 SFX ngắn — bgm tự giảm '
                                    'volume trong lúc SFX phát, tự trả về sau '
                                    'khi xong. Nghe thật trên máy để cảm nhận.',
                                    style: TextStyle(
                                      color: NeonTheme.inkSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  Text(
                                    'duckCount: $_duckDemoCount'
                                    '${_duckDemoCount > 0 ? ' (bgm ducked)' : ''}',
                                    style: TextStyle(
                                      color: NeonTheme.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  CommonButton(
                                    label: 'Play SFX (duck bgm)',
                                    onTap: _playDuckDemo,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label:
                                  'throttled() — bấm nhanh nhiều lần để so sánh',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        CommonButton(
                                          label: 'Không throttle',
                                          onTap: () =>
                                              setState(() => _plainTapCount++),
                                        ),
                                        Text('Đếm: $_plainTapCount'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: NeonTheme.s16),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        CommonButton(
                                          label: 'Có throttle',
                                          onTap: _throttledIncrement,
                                        ),
                                        Text('Đếm: $_throttledTapCount'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'CandyTextField',
                              child: CandyTextField(
                                controller: _candyTextFieldController,
                                hintText: 'Player name',
                                prefixIcon: Icons.person_outline,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Không được để trống'
                                    : null,
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Feedback & Overlay'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'LoadingOverlay',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 120,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Stack(
                                        children: [
                                          Container(color: NeonTheme.cardAlt),
                                          if (_showLoadingOverlay)
                                            const LoadingOverlay(
                                              message: 'Loading...',
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Show for 1.2s',
                                    onTap: _flashLoadingOverlay,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'ToastBanner',
                              child: CommonButton(
                                label: 'Show toast',
                                onTap: () => ToastBanner.show(
                                  context,
                                  message: 'Saved!',
                                  color: NeonTheme.lime,
                                ),
                              ),
                            ),
                            _Demo(
                              label: 'TooltipBubble',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TooltipBubble.text('Tap to pop!'),
                                  const SizedBox(width: NeonTheme.s24),
                                  TooltipBubble(
                                    color: NeonTheme.cyan,
                                    direction: TooltipPointerDirection.down,
                                    child: Text(
                                      'Combo x3',
                                      style: TextStyle(
                                        color: NeonTheme.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'BottomSheetPanel + showCommonBottomSheet',
                              child: CommonButton(
                                label: 'Open sheet',
                                onTap: _runBottomSheet,
                              ),
                            ),
                            _Demo(
                              label: 'ConfirmDialog (showConfirmDialog)',
                              child: CommonButton(
                                label: 'Delete...',
                                variant: CommonButtonVariant.danger,
                                onTap: _runConfirmDialog,
                              ),
                            ),
                            _Demo(
                              label: 'Network Banner',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: NetworkStatusBanner(
                                      key: const Key('networkBannerDemo'),
                                      connected: _networkConnected,
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: _networkConnected
                                        ? 'Go offline'
                                        : 'Go online',
                                    variant: _networkConnected
                                        ? CommonButtonVariant.danger
                                        : CommonButtonVariant.primary,
                                    onTap: () => setState(
                                      () => _networkConnected =
                                          !_networkConnected,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'ConnectivityCoordinator (FEAT-62)',
                              child: StreamBuilder<ConnectivityState>(
                                stream: _connectivity.stateStream,
                                initialData: _connectivity.state,
                                builder: (context, snapshot) {
                                  final state =
                                      snapshot.data ?? _connectivity.state;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: NetworkStatusBanner.stream(
                                          key: const Key(
                                            'connectivityCoordinatorBanner',
                                          ),
                                          connected:
                                              _connectivity.connectedStream,
                                          initialConnected: false,
                                        ),
                                      ),
                                      const SizedBox(height: NeonTheme.s8),
                                      Text('State: ${state.name}'),
                                      const SizedBox(height: NeonTheme.s16),
                                      Wrap(
                                        spacing: NeonTheme.s8,
                                        children: [
                                          CommonButton(
                                            label: 'Interface up',
                                            variant:
                                                CommonButtonVariant.secondary,
                                            onTap: () => _connectivitySignal
                                                .setHasInterface(true),
                                          ),
                                          CommonButton(
                                            label: 'Interface down',
                                            variant: CommonButtonVariant.danger,
                                            onTap: () => _connectivitySignal
                                                .setHasInterface(false),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: NeonTheme.s8),
                                      CommonButton(
                                        label: _demoProbeSucceeds
                                            ? 'Probe: OK (tap to break it)'
                                            : 'Probe: FAILING (tap to fix it)',
                                        onTap: () => setState(
                                          () => _demoProbeSucceeds =
                                              !_demoProbeSucceeds,
                                        ),
                                      ),
                                      const SizedBox(height: NeonTheme.s16),
                                      Text(
                                        'Queue: ${_connectivity.queueLength} pending, '
                                        '$_demoQueueRanCount đã chạy',
                                      ),
                                      const SizedBox(height: NeonTheme.s8),
                                      CommonButton(
                                        label: 'Enqueue demo sync task',
                                        onTap: () => setState(
                                          () => _connectivity.enqueue(
                                            QueuedTask(
                                              idempotencyKey: 'demo_sync',
                                              run: () async => setState(
                                                () => _demoQueueRanCount++,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            _Demo(
                              label: 'DeepLinkCommandRouter (FEAT-60)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CandyTextField(
                                    key: const Key('deepLinkUriField'),
                                    controller: _deepLinkController,
                                    hintText: 'Deep link URI',
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  Wrap(
                                    spacing: NeonTheme.s8,
                                    children: [
                                      CommonButton(
                                        label: 'Simulate link',
                                        onTap: () async {
                                          final uri = Uri.tryParse(
                                            _deepLinkController.text,
                                          );
                                          if (uri == null) {
                                            setState(
                                              () => _deepLinkLog =
                                                  'URI không hợp lệ.',
                                            );
                                            return;
                                          }
                                          final result = await _deepLinks
                                              .handleUri(uri);
                                          if (!mounted) return;
                                          setState(
                                            () => _deepLinkLog =
                                                'outcome: ${result.outcome.name}',
                                          );
                                        },
                                      ),
                                      CommonButton(
                                        label: 'Simulate lại (duplicate)',
                                        variant: CommonButtonVariant.secondary,
                                        onTap: () async {
                                          final uri = Uri.tryParse(
                                            _deepLinkController.text,
                                          );
                                          if (uri == null) return;
                                          final result = await _deepLinks
                                              .handleUri(uri);
                                          if (!mounted) return;
                                          setState(
                                            () => _deepLinkLog =
                                                'outcome: ${result.outcome.name}',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  Text(_deepLinkLog),
                                  const SizedBox(height: NeonTheme.s8),
                                  Text(
                                    'Thật: adb shell am start -a android.intent.action.VIEW '
                                    '-d "roycasualkit://open/level/5"',
                                    style: TextStyle(
                                      color: NeonTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'AppVersionGate (FEAT-59)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CommonButton(
                                    label:
                                        'Scenario: $_versionGateScenario (bấm để đổi)',
                                    onTap: () async {
                                      const order = [
                                        'ok',
                                        'soft',
                                        'force',
                                        'maintenance',
                                      ];
                                      final next =
                                          order[(order.indexOf(
                                                    _versionGateScenario,
                                                  ) +
                                                  1) %
                                              order.length];
                                      // Instance MỚI mỗi lần đổi scenario —
                                      // RemoteConfigService.init() không reset
                                      // _config khi load asset lỗi (giữ config
                                      // cũ làm fallback, đúng ý ENH-58), nên
                                      // gọi lại init() nhiều lần trên CÙNG 1
                                      // instance sẽ TÍCH LUỸ key cũ thay vì
                                      // thay hẳn — không đúng ý demo "đổi hẳn
                                      // sang scenario khác".
                                      final remoteConfig = RemoteConfigService(
                                        assetPath:
                                            'assets/nonexistent_app_version_gate.json',
                                        fetchRemote: () async {
                                          switch (next) {
                                            case 'soft':
                                              return {
                                                'appVersionRecommended':
                                                    '9999.0.0',
                                              };
                                            case 'force':
                                              return {
                                                'appVersionMinimum': '9999.0.0',
                                              };
                                            case 'maintenance':
                                              return {
                                                'appVersionMaintenanceActive':
                                                    true,
                                                'appVersionMaintenanceMessage':
                                                    'Đang bảo trì demo, quay lại sau nhé.',
                                              };
                                            default:
                                              return {};
                                          }
                                        },
                                      );
                                      await remoteConfig.init();
                                      if (!mounted) return;
                                      setState(() {
                                        _versionGateScenario = next;
                                        _versionGateRemoteConfig = remoteConfig;
                                        _versionGate = AppVersionGateController(
                                          remoteConfig: remoteConfig,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      height: 320,
                                      child: AppVersionGateOverlay(
                                        decision: _versionGate.decisionFor(
                                          kAppVersion,
                                        ),
                                        config: _versionGate.config,
                                        launchStore: (url) async {
                                          ToastBanner.show(
                                            context,
                                            message: 'Mở store: $url',
                                            color: NeonTheme.cyan,
                                          );
                                          return true;
                                        },
                                        onSoftDismiss: () => setState(
                                          () => _versionGate
                                              .recordSoftPromptDismissed(),
                                        ),
                                        child: Container(
                                          color: NeonTheme.card,
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'Nội dung app (demo)',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'Shimmer Loading',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_showShimmer)
                                    const Column(
                                      children: [
                                        ShimmerPlaceholder(
                                          height: 48,
                                          borderRadius: 12,
                                        ),
                                        SizedBox(height: NeonTheme.s8),
                                        ShimmerPlaceholder(
                                          height: 48,
                                          borderRadius: 12,
                                        ),
                                      ],
                                    )
                                  else
                                    const CommonListTile(
                                      title: 'Shop item loaded',
                                      subtitle: 'Content ready',
                                    ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: _showShimmer
                                        ? 'Show loaded content'
                                        : 'Show shimmer',
                                    onTap: () => setState(
                                      () => _showShimmer = !_showShimmer,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Progress & Reward'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'ProgressBarStars',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ProgressBarStars(progress: _progress),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: '+20% progress',
                                    onTap: _bumpProgress,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'CircularProgressRing',
                              child: CircularProgressRing(
                                progress: _progress,
                                label: '${(_progress * 100).round()}%',
                              ),
                            ),
                            _Demo(
                              label: 'StarRating',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StarRating(
                                    earned: _starsEarned,
                                    animate: false,
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Cycle stars',
                                    onTap: _cycleStars,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'CurrencyCounter',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Wrap (not Row) — on a narrower effective
                                  // width (larger system font scale / display
                                  // zoom, e.g. reproduced on a real Samsung
                                  // device with font_scale 1.08 + a density
                                  // override), 3 fixed-width items in a plain
                                  // Row(mainAxisSize.min) overflow instead of
                                  // shrinking; Wrap just flows the 3rd item to
                                  // a new line instead.
                                  Wrap(
                                    spacing: NeonTheme.s16,
                                    runSpacing: NeonTheme.s8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      CurrencyCounter(
                                        key: _coinCounterKey,
                                        value: _coins,
                                      ),
                                      CommonButton(
                                        label: '+25',
                                        width: 90,
                                        onTap: _bumpCoins,
                                      ),
                                      // FEAT-12: coins fly from the bottom of
                                      // the screen to this CurrencyCounter's
                                      // GlobalKey, bumping the value on arrival
                                      // instead of jumping instantly.
                                      CommonButton(
                                        label: 'Fly +25',
                                        width: 110,
                                        color: NeonTheme.gold,
                                        onTap: _flyCoins,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  // Idle-game scale value — shows
                                  // fmtNumCompact's K/M/B rounding (ENH-11)
                                  // instead of a raw digit string.
                                  const CurrencyCounter(value: 12345678),
                                ],
                              ),
                            ),
                            _Demo(
                              // FloatingComboText.show() inserts into the root
                              // Overlay (screen-wide), so it pops centered over
                              // the whole screen rather than inside this card —
                              // tap repeatedly to see the spam behavior.
                              label: 'FloatingComboText',
                              child: CommonButton(
                                label: 'Spam combo x5',
                                color: NeonTheme.gold,
                                onTap: _spamComboText,
                              ),
                            ),
                            _Demo(
                              label: 'RewardPopup',
                              child: CommonButton(
                                label: 'Show reward',
                                color: NeonTheme.gold,
                                onTap: _openRewardPopup,
                              ),
                            ),
                            _Demo(
                              label: 'ConfettiOverlay',
                              child: SizedBox(
                                height: 160,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: CommonButton(
                                        label: 'Trigger',
                                        onTap: _fireConfetti,
                                      ),
                                    ),
                                    if (_confettiActive)
                                      Positioned.fill(
                                        child: ConfettiOverlay(
                                          key: ValueKey(_confettiTrigger),
                                          onFinished: () {
                                            if (mounted) {
                                              setState(
                                                () => _confettiActive = false,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            _Demo(
                              // Highlights the "Primary" CommonButton up in
                              // Buttons & Interactive (keyed via
                              // _spotlightTargetKey) — scroll up after
                              // dismissing to see which one it was.
                              label: 'SpotlightOverlay',
                              child: CommonButton(
                                label: 'Start tutorial',
                                onTap: _startTutorial,
                              ),
                            ),
                            _Demo(
                              label: 'TutorialSequence',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CommonButton(
                                    label: 'Start 2-step tutorial',
                                    onTap: _startTutorialSequence,
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  CommonButton(
                                    label: 'Start from JSON (IDEA-35)',
                                    variant: CommonButtonVariant.secondary,
                                    onTap: _startTutorialSequenceFromJson,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'OnboardingCoordinatorService (IDEA-54)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Next eligible flow: '
                                    '${_onboarding.nextEligibleFlow() ?? "(none — all seen)"}',
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  CommonButton(
                                    label: 'Run next onboarding flow',
                                    onTap:
                                        _onboarding.nextEligibleFlow() == null
                                        ? null
                                        : _runNextOnboardingFlow,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'BadgeDot',
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 32,
                                    color: NeonTheme.ink,
                                  ),
                                  const Positioned(
                                    top: -2,
                                    right: -2,
                                    child: BadgeDot(),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'StreakCounter',
                              child: const StreakCounter(days: 7),
                            ),
                            _Demo(
                              label: 'CountdownChip',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // No key here (BUG-30 fix demo): tapping
                                  // "Restart 15s" changes `target` on this SAME
                                  // CountdownChip instance — didUpdateWidget
                                  // must pick up the new target and restart the
                                  // ticking, not require a remount to notice it.
                                  CountdownChip(
                                    target: _countdownTarget,
                                    onDone: () => ToastBanner.show(
                                      context,
                                      message: 'Countdown done!',
                                      color: NeonTheme.orange,
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Restart 15s',
                                    onTap: () => setState(
                                      () => _countdownTarget = DateTime.now()
                                          .add(const Duration(seconds: 15)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label:
                                  'PersistentCooldownService + CooldownCountdownChip',
                              child: Obx(() {
                                // Obx tracks whichever .obs .value getters
                                // run inside this closure — reading
                                // revision.value here is what makes it
                                // rebuild on start/cancel; remainingOf()
                                // itself touches no Rx value.
                                _cooldown.revision.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CooldownCountdownChip(
                                      remaining: _cooldown.remainingOf(
                                        'demo_booster',
                                      ),
                                      onDone: () => ToastBanner.show(
                                        context,
                                        message: 'Booster cooldown ready!',
                                        color: NeonTheme.cyan,
                                      ),
                                    ),
                                    const SizedBox(height: NeonTheme.s16),
                                    CommonButton(
                                      label: 'Start 12s cooldown',
                                      onTap: () => _cooldown.start(
                                        'demo_booster',
                                        const Duration(seconds: 12),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'Page Dots',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 80,
                                    child: PageView(
                                      controller: _dotsPageController,
                                      onPageChanged: (i) =>
                                          setState(() => _dotsPageIndex = i),
                                      children: List.generate(
                                        4,
                                        (i) => Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: NeonTheme.cardAlt,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'Page ${i + 1}',
                                            style: TextStyle(
                                              color: NeonTheme.ink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  Center(
                                    child: PaginatedDotsIndicator(
                                      count: 4,
                                      currentIndex: _dotsPageIndex,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            _Demo(
                              label: 'DailyLoginCalendarWidget',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DailyLoginCalendarWidget(
                                    currentStreakDay:
                                        _dailyLogin.currentStreakDay,
                                    claimedDaysInCycle:
                                        _dailyLogin.claimedDaysInCycle,
                                    canClaimToday: _dailyLogin.canClaimToday(),
                                    onClaim: _claimDailyLogin,
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  // IDEA-49: longestStreakEver keeps counting
                                  // past the 7-day calendar cycle and never
                                  // resets, unlike currentStreakDay above.
                                  Text(
                                    'Longest streak ever: '
                                    '${_dailyLogin.longestStreakEver}',
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'EnergyBar',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  EnergyBar(
                                    currentEnergy: _energy.currentEnergy,
                                    maxEnergy: _energy.maxEnergy,
                                    timeUntilNextEnergy:
                                        _energy.timeUntilNextEnergy,
                                    hasInfiniteLives: _energy.hasInfiniteLives,
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Consume 1 energy',
                                    onTap: _consumeEnergy,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'WheelSpinner',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  WheelSpinner(
                                    segments: _wheelSegments,
                                    controller: _wheelController,
                                    onSpinEnd: (segment) => ToastBanner.show(
                                      context,
                                      message: 'Landed on ${segment.label}!',
                                      color: NeonTheme.gold,
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Spin',
                                    onTap: _spinWheel,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Layout & Cards'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'CommonListTile',
                              child: Column(
                                children: [
                                  CommonListTile(
                                    title: 'Daily Reward',
                                    subtitle: 'Claim your coins',
                                    leading: Icon(
                                      Icons.card_giftcard_rounded,
                                      color: NeonTheme.magenta,
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: () {},
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  CommonListTile(
                                    title: 'Leaderboard',
                                    leading: Icon(
                                      Icons.leaderboard_rounded,
                                      color: NeonTheme.cyan,
                                    ),
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label:
                                  'LeaderboardList (IDEA-46: LocalScoreboardService)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LeaderboardList(
                                    entries: [
                                      for (final entry
                                          in _showRankAround
                                              ? _scoreboard.entriesAround(
                                                  'You',
                                                  radius: 1,
                                                )
                                              : _scoreboard.topN(3))
                                        LeaderboardEntry(
                                          rank: entry.rank,
                                          name: entry.name,
                                          score: entry.score,
                                          highlighted: entry.name == 'You',
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Submit random score',
                                    onTap: _submitRandomScore,
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  CommonButton(
                                    label: _showRankAround
                                        ? 'Show top 3'
                                        : 'Show rank around me (IDEA-48)',
                                    variant: CommonButtonVariant.secondary,
                                    onTap: () => setState(
                                      () => _showRankAround = !_showRankAround,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'QuestBoardPanel (IDEA-44)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  QuestBoardPanel(
                                    quests: [
                                      _questWinMatches,
                                      _questUseBooster,
                                    ],
                                    onClaim: _claimQuest,
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Thắng 1 trận',
                                    onTap: _bumpQuestProgress,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'EmptyStatePlaceholder',
                              child: const EmptyStatePlaceholder(
                                icon: Icons.inbox_outlined,
                                message: 'Nothing here yet.',
                              ),
                            ),
                            _Demo(
                              label: 'RetryErrorState',
                              child: RetryErrorState.fromSdkFailure(
                                const SdkFailure(
                                  kind: SdkErrorKind.network,
                                  message: 'Could not reach the server.',
                                ),
                                compact: true,
                                onRetry: () => Future<void>.delayed(
                                  const Duration(milliseconds: 800),
                                ),
                              ),
                            ),
                            _Demo(
                              label: 'AvatarFrame',
                              child: AvatarFrame(
                                color: NeonTheme.magenta,
                                child: Container(
                                  color: NeonTheme.cardAlt,
                                  alignment: Alignment.center,
                                  child: Text(
                                    'RB',
                                    style: TextStyle(
                                      color: NeonTheme.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _Demo(
                              label:
                                  'VictoryCardTemplate (share_helper wiring)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RepaintBoundary(
                                    key: _victoryCardKey,
                                    child: VictoryCardTemplate(
                                      title: 'Level 50 Complete!',
                                      statLines: const [
                                        'Score: 12,340',
                                        'Time: 01:23',
                                      ],
                                      avatar: const CircleAvatar(
                                        child: Text('RB'),
                                      ),
                                      qrData:
                                          'https://example.com/invite/abc123',
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Share',
                                    width: 140,
                                    onTap: _shareVictoryCard,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'GameOverCardTemplate',
                              child: GameOverCardTemplate(
                                title: 'Out of moves!',
                                message: 'So close — try again?',
                                icon: Icons.sentiment_dissatisfied_rounded,
                                statLines: const ['Score: 1,200'],
                                primaryActionLabel: 'Retry',
                                onPrimaryAction: () => ToastBanner.show(
                                  context,
                                  message: 'Retry tapped',
                                  color: NeonTheme.cyan,
                                ),
                                secondaryActionLabel: 'Home',
                                onSecondaryAction: () => ToastBanner.show(
                                  context,
                                  message: 'Home tapped',
                                  color: NeonTheme.muted,
                                ),
                              ),
                            ),
                            _Demo(
                              label: 'BackupRestorePanel',
                              child: BackupRestorePanel(
                                secret: 'showcase-demo-secret',
                                onExport: (json) async {
                                  _lastBackup = json;
                                },
                                onImport: () async => _lastBackup,
                              ),
                            ),
                            _Demo(
                              label: 'SaveSlotManager (IDEA-56)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final slot in _saveSlots.listSlots())
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: NeonTheme.s8,
                                      ),
                                      child: CommonListTile(
                                        title: slot.displayName,
                                        subtitle:
                                            'Demo score: ${_demoScoreFor(slot.id)}'
                                            '${slot.id == _saveSlots.activeSlotId ? " • Active" : ""}',
                                        trailing: IconButton(
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: NeonTheme.red,
                                          ),
                                          onPressed: () => _deleteSaveSlot(
                                            slot.id,
                                            slot.displayName,
                                          ),
                                        ),
                                        onTap: () =>
                                            _setActiveSaveSlot(slot.id),
                                      ),
                                    ),
                                  if (_saveSlots.listSlots().isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        bottom: NeonTheme.s8,
                                      ),
                                      child: Text('No slots yet.'),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CommonButton(
                                          label: 'Create slot',
                                          onTap: _createSaveSlot,
                                        ),
                                      ),
                                      const SizedBox(width: NeonTheme.s8),
                                      Expanded(
                                        child: CommonButton(
                                          label: '+10 score',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: _saveSlots.activeSlotId == null
                                              ? null
                                              : _addDemoScoreToActiveSlot,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'ConsentStateService (FEAT-61)',
                              child: Obx(() {
                                // Obx tracks whichever .obs .value getters run
                                // inside this closure — reading revision.value
                                // is what makes it rebuild on grant/deny/reset.
                                _consent.revision.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Analytics: ${_consent.statusOf(ConsentCategory.analytics).name}',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    Wrap(
                                      spacing: NeonTheme.s8,
                                      children: [
                                        CommonButton(
                                          label: 'Grant analytics',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () => _consent.grant(
                                            ConsentCategory.analytics,
                                          ),
                                        ),
                                        CommonButton(
                                          label: 'Deny analytics',
                                          variant: CommonButtonVariant.danger,
                                          onTap: () => _consent.deny(
                                            ConsentCategory.analytics,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: NeonTheme.s16),
                                    Text(
                                      'Personalization: ${_consent.statusOf(ConsentCategory.personalization).name}',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    Wrap(
                                      spacing: NeonTheme.s8,
                                      children: [
                                        CommonButton(
                                          label: 'Grant personalization',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () => _consent.grant(
                                            ConsentCategory.personalization,
                                          ),
                                        ),
                                        CommonButton(
                                          label: 'Deny personalization',
                                          variant: CommonButtonVariant.danger,
                                          onTap: () => _consent.deny(
                                            ConsentCategory.personalization,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: NeonTheme.s16),
                                    Text(
                                      'Demo events actually logged: $_demoAnalyticsEventCount',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    CommonButton(
                                      label: 'Log demo event (gated)',
                                      onTap: () => _gatedAnalytics.logEvent(
                                        'demo_event',
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'ExperimentBucketingService (IDEA-57)',
                              child: Obx(() {
                                _consent.revision.value;
                                final personalizationGranted = _consent
                                    .isGranted(ConsentCategory.personalization);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      personalizationGranted
                                          ? 'Experiment "$_demoExperimentKey" → '
                                                '${_experiments.variantFor(_demoExperimentKey, _demoExperimentVariants)}'
                                          : 'Experiment "$_demoExperimentKey" → '
                                                'blocked (no personalization consent)',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text(
                                      'Device id: '
                                      '${_experiments.anonymousId.substring(0, 8)}…',
                                      style: TextStyle(color: NeonTheme.muted),
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'AppSessionTracker (FEAT-63)',
                              child: Obx(() {
                                // Obx tracks _consent.revision.value để rebuild
                                // đúng lúc consent analytics đổi (ảnh hưởng
                                // analyticsContext() bên dưới).
                                _consent.revision.value;
                                final context = _sessionTracker
                                    .analyticsContext();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Session #${_sessionTracker.current.sequence} '
                                      '(id: ${_sessionTracker.current.sessionId.substring(0, 8)}…)',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text(
                                      'Foreground: '
                                      '${fmtDur(_sessionTracker.foregroundDuration)}',
                                    ),
                                    const SizedBox(height: NeonTheme.s16),
                                    CommonButton(
                                      label: 'Refresh',
                                      variant: CommonButtonVariant.secondary,
                                      onTap: () => setState(() {}),
                                    ),
                                    const SizedBox(height: NeonTheme.s16),
                                    Text(
                                      context.isEmpty
                                          ? 'Analytics context: {} (chưa có analytics consent)'
                                          : 'Analytics context: ${jsonEncode(context)}',
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'PlatformCapabilityRegistry (FEAT-71)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Platform: ${_platformCapabilities.snapshot.platformKind.name}',
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  Text(
                                    'Haptics: ${_platformCapabilities.snapshot.supportsHaptics}  '
                                    '· Shaders: ${_platformCapabilities.snapshot.supportsShaders}',
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  Text(
                                    'Notifications: ${_platformCapabilities.snapshot.supportsNotifications}  '
                                    '· Background audio: ${_platformCapabilities.snapshot.supportsBackgroundAudio}',
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Fire haptic (with fallback)',
                                    onTap: () => _platformCapabilities
                                        .withFallback<void>(
                                          supported: _platformCapabilities
                                              .snapshot
                                              .supportsHaptics,
                                          ifSupported: () {
                                            fireHaptic(HapticLevel.light);
                                            ToastBanner.show(
                                              context,
                                              message: 'Haptic fired',
                                              color: NeonTheme.cyan,
                                            );
                                          },
                                          fallback: () => ToastBanner.show(
                                            context,
                                            message:
                                                'Haptics not supported here — fallback: no-op',
                                            color: NeonTheme.muted,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'AssetPreloadCoordinator (FEAT-47)',
                              child: Obx(() {
                                final progress = _assetPreload.progress.value;
                                final phase =
                                    _assetSession.snapshot.value.phase;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LinearProgressIndicator(value: progress),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text(
                                      'Progress: ${(progress * 100).toStringAsFixed(0)}%  '
                                      '· Session phase: ${phase.name}',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text(_assetDemoStatus),
                                    const SizedBox(height: NeonTheme.s16),
                                    Wrap(
                                      spacing: NeonTheme.s8,
                                      runSpacing: NeonTheme.s8,
                                      children: [
                                        CommonButton(
                                          label: 'Preload OK',
                                          onTap: () =>
                                              _runAssetDemoPreload('ok'),
                                        ),
                                        CommonButton(
                                          label: 'Preload (optional fail)',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () => _runAssetDemoPreload(
                                            'optionalFail',
                                          ),
                                        ),
                                        CommonButton(
                                          label: 'Preload (required fail)',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () => _runAssetDemoPreload(
                                            'requiredFail',
                                          ),
                                        ),
                                        CommonButton(
                                          label: 'Cancel',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: _assetPreload.cancel,
                                        ),
                                        CommonButton(
                                          label: 'Retry failed',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () async {
                                            final result = await _assetPreload
                                                .retryFailed();
                                            if (!mounted) return;
                                            setState(() {
                                              if (result is SdkSuccess<void>) {
                                                _assetSession.markReady();
                                                _assetSession.start();
                                                _assetDemoStatus =
                                                    'Retry OK — scene sẵn sàng.';
                                              } else if (result
                                                  is SdkFailure<void>) {
                                                _assetDemoStatus =
                                                    'Retry vẫn fail: ${result.message}';
                                              }
                                            });
                                          },
                                        ),
                                        CommonButton(
                                          label: 'Unload scene',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () {
                                            _assetPreload.unloadScene();
                                            _assetSession.restart();
                                            setState(
                                              () => _assetDemoStatus =
                                                  'Đã unload scene.',
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'SceneTransitionOverlay (FEAT-58)',
                              child: Obx(() {
                                final phase = _sceneTransition.phase.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 320,
                                      child: SceneTransitionOverlay(
                                        controller: _sceneTransition,
                                        onRetry: () => _sceneTransition.retry(
                                          _sceneDemoLoad,
                                        ),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: NeonTheme.cardAlt,
                                            borderRadius: BorderRadius.circular(
                                              NeonTheme.s16,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Scene #$_sceneRevision',
                                              style: TextStyle(
                                                color: NeonTheme.ink,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text('Phase: ${phase.name}'),
                                    const SizedBox(height: NeonTheme.s16),
                                    Wrap(
                                      spacing: NeonTheme.s8,
                                      runSpacing: NeonTheme.s8,
                                      children: [
                                        CommonButton(
                                          label: 'Chuyển scene (OK)',
                                          onTap: () async {
                                            _sceneDemoForceFail = false;
                                            final result =
                                                await _sceneTransition.run(
                                                  _sceneDemoLoad,
                                                );
                                            if (!mounted) return;
                                            if (result is SdkSuccess<void>) {
                                              setState(() => _sceneRevision++);
                                            }
                                          },
                                        ),
                                        CommonButton(
                                          label: 'Chuyển scene (lỗi)',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () {
                                            _sceneDemoForceFail = true;
                                            _sceneTransition.run(
                                              _sceneDemoLoad,
                                            );
                                          },
                                        ),
                                        CommonButton(
                                          label: 'Cancel transition',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: _sceneTransition.cancel,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'PlayerProgressionService (FEAT-43)',
                              child: Obx(() {
                                final snap = _progression.snapshot.value;
                                final progress = snap.isMaxLevel
                                    ? 1.0
                                    : snap.xpIntoLevel / snap.xpToNextLevel;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Level ${snap.level}'
                                      '${snap.isMaxLevel ? ' (MAX)' : ''}',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    LinearProgressIndicator(value: progress),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text(
                                      snap.isMaxLevel
                                          ? 'Total XP: ${snap.totalXpEarned}'
                                          : 'XP: ${snap.xpIntoLevel}/${snap.xpToNextLevel}'
                                                ' (total: ${snap.totalXpEarned})',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text(
                                      'Unlock gems: ${_progressionWallet.balanceOf('gem')}',
                                    ),
                                    const SizedBox(height: NeonTheme.s16),
                                    Wrap(
                                      spacing: NeonTheme.s8,
                                      runSpacing: NeonTheme.s8,
                                      children: [
                                        CommonButton(
                                          label: 'Grant 50 XP',
                                          onTap: () =>
                                              _grantProgressionXp(context, 50),
                                        ),
                                        CommonButton(
                                          label: 'Grant 300 XP (multi-level)',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () =>
                                              _grantProgressionXp(context, 300),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'InventoryService (FEAT-44)',
                              child: Obx(() {
                                final snap = _inventory.snapshot.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Slots: ${snap.slots.length}/${snap.capacity}',
                                    ),
                                    const SizedBox(height: NeonTheme.s8),
                                    for (final slot in snap.slots)
                                      Text(
                                        '${slot.itemId} x${slot.quantity}'
                                        '${slot.equipped ? ' (equipped)' : ''}',
                                      ),
                                    if (snap.slots.isEmpty)
                                      const Text('(rỗng)'),
                                    const SizedBox(height: NeonTheme.s8),
                                    Text(_inventoryStatus),
                                    const SizedBox(height: NeonTheme.s16),
                                    Wrap(
                                      spacing: NeonTheme.s8,
                                      runSpacing: NeonTheme.s8,
                                      children: [
                                        CommonButton(
                                          label: 'Grant potion x3',
                                          onTap: () =>
                                              _inventoryGrant('potion', 3),
                                        ),
                                        CommonButton(
                                          label: 'Consume potion x2',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () =>
                                              _inventoryConsume('potion', 2),
                                        ),
                                        CommonButton(
                                          label: 'Grant sword',
                                          onTap: () =>
                                              _inventoryGrant('sword', 1),
                                        ),
                                        CommonButton(
                                          label: 'Equip sword',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () {
                                            final swords = snap.slotsFor(
                                              'sword',
                                            );
                                            if (swords.isEmpty) return;
                                            final swordSlot = swords.first;
                                            _inventory.setEquipped(
                                              slotId: swordSlot.slotId,
                                              equipped: !swordSlot.equipped,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ),
                            _Demo(
                              label: 'InventoryGrid (FEAT-56)',
                              child: Obx(() {
                                final snap = _inventory.snapshot.value;
                                return SizedBox(
                                  height: 200,
                                  child: InventoryGrid(
                                    snapshot: snap,
                                    unlockedCapacity: 3,
                                    crossAxisCount: 4,
                                    selectedSlotId: _selectedInventorySlotId,
                                    onSlotTap: (slot) => setState(
                                      () => _selectedInventorySlotId =
                                          _selectedInventorySlotId ==
                                              slot.slotId
                                          ? null
                                          : slot.slotId,
                                    ),
                                    onReorder: (from, to) =>
                                        _inventory.moveSlot(
                                          fromSlotId: from,
                                          toSlotId: to,
                                        ),
                                    itemBuilder: (context, slot, isSelected) {
                                      final def =
                                          _inventoryCatalog[slot.itemId];
                                      final rarityColor = switch (def?.rarity) {
                                        ItemRarity.rare => NeonTheme.cyan,
                                        ItemRarity.epic => NeonTheme.purple,
                                        ItemRarity.legendary => NeonTheme.gold,
                                        _ => NeonTheme.inkSoft,
                                      };
                                      return DecoratedBox(
                                        key: ValueKey(
                                          'inv_grid_tile_${slot.slotId}',
                                        ),
                                        decoration: BoxDecoration(
                                          color: NeonTheme.card,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? NeonTheme.gold
                                                : rarityColor,
                                            width: isSelected ? 3 : 2,
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              slot.itemId,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: NeonTheme.ink,
                                              ),
                                            ),
                                            if (slot.quantity > 1)
                                              Positioned(
                                                right: 2,
                                                bottom: 2,
                                                child: Text(
                                                  'x${slot.quantity}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: NeonTheme.ink,
                                                  ),
                                                ),
                                              ),
                                            if (slot.equipped)
                                              const Positioned(
                                                left: 2,
                                                top: 2,
                                                child: Icon(
                                                  Icons.check_circle,
                                                  size: 12,
                                                  color: Colors.green,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }),
                            ),
                            _Demo(
                              label: 'OfflineOutboxService (FEAT-67)',
                              child: Obx(() {
                                final pending = _outbox.items
                                    .where((i) => !i.manualReview)
                                    .toList();
                                final manual = _outbox.manualReviewItems;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pending: ${pending.length}  · '
                                      'Manual review: ${manual.length}',
                                    ),
                                    for (final item in pending)
                                      Text(
                                        '${item.idempotencyKey}: '
                                        '${item.payload['score']}',
                                      ),
                                    for (final item in manual)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: NeonTheme.s8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Conflict ${item.idempotencyKey}: '
                                              'local ${item.payload['score']} '
                                              'vs server ${item.remotePayload?['score']}',
                                            ),
                                            Wrap(
                                              spacing: NeonTheme.s8,
                                              children: [
                                                CommonButton(
                                                  label: 'Keep local',
                                                  variant: CommonButtonVariant
                                                      .secondary,
                                                  onTap: () =>
                                                      _outbox.resolveManual(
                                                        idempotencyKey:
                                                            item.idempotencyKey,
                                                        resolution:
                                                            ManualResolution
                                                                .keepLocal,
                                                      ),
                                                ),
                                                CommonButton(
                                                  label: 'Accept remote',
                                                  variant: CommonButtonVariant
                                                      .secondary,
                                                  onTap: () =>
                                                      _outbox.resolveManual(
                                                        idempotencyKey:
                                                            item.idempotencyKey,
                                                        resolution:
                                                            ManualResolution
                                                                .acceptRemote,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: NeonTheme.s16),
                                    Wrap(
                                      spacing: NeonTheme.s8,
                                      runSpacing: NeonTheme.s8,
                                      children: [
                                        CommonButton(
                                          label: 'Enqueue OK',
                                          onTap: () {
                                            _outboxCounter++;
                                            _outbox.enqueue(
                                              idempotencyKey:
                                                  'score_$_outboxCounter',
                                              payload: {
                                                'score': _outboxCounter * 10,
                                              },
                                            );
                                          },
                                        ),
                                        CommonButton(
                                          label: 'Enqueue (conflict)',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () {
                                            _outboxCounter++;
                                            _outbox.enqueue(
                                              idempotencyKey:
                                                  'score_$_outboxCounter',
                                              payload: {
                                                'score': _outboxCounter * 10,
                                                'forceConflict': true,
                                              },
                                            );
                                          },
                                        ),
                                        CommonButton(
                                          label: 'Drain now',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: _outbox.drain,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Adaptive HUD'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'AdaptiveGameHud (FEAT-52)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ClipRect(
                                    child: ColoredBox(
                                      color: NeonTheme.bgMid,
                                      child: SizedBox(
                                        height: 240,
                                        child: AdaptiveGameHud(
                                          debugShowBounds: _hudDebugBounds,
                                          compactBreakpointWidth: 500,
                                          slots: {
                                            HudSlot.topStart: const _HudChip(
                                              'HUD score: 900',
                                            ),
                                            HudSlot.topEnd: const _HudChip(
                                              'HUD pause',
                                            ),
                                            HudSlot.bottom: const _HudChip(
                                              'HUD lives 3 · coins 350',
                                            ),
                                            HudSlot.side: const _HudChip(
                                              'HUD boost',
                                            ),
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  CommonButton(
                                    label: _hudDebugBounds
                                        ? 'Ẩn debug bounds'
                                        : 'Hiện debug bounds',
                                    variant: CommonButtonVariant.secondary,
                                    onTap: () => setState(
                                      () => _hudDebugBounds = !_hudDebugBounds,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Level Select'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'LevelSelectGrid',
                              child: LevelSelectGrid(
                                states: _levelStates,
                                starsEarnedByLevel: _levelStars,
                                onLevelTap: (level) => ToastBanner.show(
                                  context,
                                  message: 'Level $level tapped',
                                  color: NeonTheme.cyan,
                                ),
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Reward Choice'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'RewardChoicePanel',
                              child: RewardChoicePanel(
                                options: _rewardChoices,
                                onConfirm: (ids) async {
                                  await Future<void>.delayed(
                                    const Duration(milliseconds: 500),
                                  );
                                  if (context.mounted) {
                                    ToastBanner.show(
                                      context,
                                      message: 'Granted: ${ids.join(', ')}',
                                      color: NeonTheme.cyan,
                                    );
                                  }
                                },
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Shop'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'RibbonBadge',
                              child: Wrap(
                                spacing: NeonTheme.s16,
                                runSpacing: NeonTheme.s16,
                                children: [
                                  RibbonBadge(
                                    text: 'SALE',
                                    child: SizedBox(
                                      width: 100,
                                      height: 80,
                                      child: PanelCard(
                                        alt: true,
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                  RibbonBadge(
                                    text: 'NEW',
                                    color: NeonTheme.lime,
                                    child: SizedBox(
                                      width: 100,
                                      height: 80,
                                      child: PanelCard(
                                        alt: true,
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label:
                                  'ShopItemCard (IDEA-47: PurchaseLedgerService)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Gems: ${_purchases.balanceOf(_gemsSku)}',
                                    style: TextStyle(
                                      color: NeonTheme.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  Wrap(
                                    spacing: NeonTheme.s16,
                                    runSpacing: NeonTheme.s16,
                                    children: [
                                      ShopItemCard(
                                        icon: Icons.diamond_rounded,
                                        title: '100 Gems',
                                        priceLabel: r'$0.99',
                                        onBuy: () => _buyGems(100),
                                      ),
                                      ShopItemCard(
                                        icon: Icons.diamond_rounded,
                                        title: 'Mega Gem Pack',
                                        priceLabel: r'$4.99',
                                        ribbonText: 'BEST VALUE',
                                        ribbonColor: NeonTheme.gold,
                                        iconColor: NeonTheme.gold,
                                        onBuy: () => _buyGems(500),
                                      ),
                                      ShopItemCard(
                                        icon: Icons.block_rounded,
                                        title: 'Remove Ads',
                                        priceLabel:
                                            _purchases.owns(_removeAdsSku)
                                            ? 'Owned'
                                            : r'$2.99',
                                        ribbonText: 'NEW',
                                        ribbonColor: NeonTheme.lime,
                                        onBuy: _purchases.owns(_removeAdsSku)
                                            ? null
                                            : _buyRemoveAds,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                            const SectionHeader(title: 'Game Feel'),
                            const SizedBox(height: NeonTheme.s16),
                            _Demo(
                              label: 'SquashStretch (tap the card)',
                              child: SquashStretch(
                                onTap: _bumpSquashTapCount,
                                child: PanelCard(
                                  alt: true,
                                  child: SizedBox(
                                    width: 120,
                                    height: 60,
                                    child: Center(
                                      child: Text(
                                        'Taps: $_squashTapCount',
                                        style: TextStyle(
                                          color: NeonTheme.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _Demo(
                              label: 'ScreenShake',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ScreenShake(
                                    controller: _screenShakeController,
                                    child: PanelCard(
                                      alt: true,
                                      child: SizedBox(
                                        width: 120,
                                        height: 60,
                                        child: Center(
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            color: NeonTheme.orange,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Shake!',
                                    onTap: () => _screenShakeController.shake(),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'ComboHeatBackground',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ComboHeatBackground(
                                    heat: _comboHeat,
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 60,
                                      child: Center(
                                        child: Text(
                                          'Heat: ${(_comboHeat * 100).round()}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NeonTheme.s16),
                                  CommonButton(
                                    label: 'Bump heat',
                                    onTap: _cycleComboHeat,
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'HapticChoreographer (IDEA-41)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CommonButton(
                                          label: 'Reward',
                                          onTap: () =>
                                              _playHaptic(HapticPattern.reward),
                                        ),
                                      ),
                                      const SizedBox(width: NeonTheme.s8),
                                      Expanded(
                                        child: CommonButton(
                                          label: 'Combo',
                                          variant:
                                              CommonButtonVariant.secondary,
                                          onTap: () =>
                                              _playHaptic(HapticPattern.combo),
                                        ),
                                      ),
                                      const SizedBox(width: NeonTheme.s8),
                                      Expanded(
                                        child: CommonButton(
                                          label: 'Error',
                                          variant: CommonButtonVariant.danger,
                                          onTap: () =>
                                              _playHaptic(HapticPattern.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  Text(
                                    'Pulses fired: ${_hapticLog?.isEmpty ?? true ? '(none yet)' : _hapticLog}',
                                    style: TextStyle(
                                      color: NeonTheme.inkSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Demo(
                              label: 'AchievementUnlockListener (IDEA-43)',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _achievements.isCompleted(
                                          'widget_kit_explorer',
                                        )
                                        ? 'widget_kit_explorer: unlocked!'
                                        : 'widget_kit_explorer: $_achievementTaps / 3',
                                    style: TextStyle(color: NeonTheme.ink),
                                  ),
                                  const SizedBox(height: NeonTheme.s8),
                                  CommonButton(
                                    label: 'Tap to progress',
                                    onTap: _bumpAchievementProgress,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: NeonTheme.s24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_rewardPopupOpen)
                Positioned.fill(
                  child: NeonDialog.overlay(
                    onBarrier: _closeRewardPopup,
                    panel: GestureDetector(
                      onTap: _closeRewardPopup,
                      child: RewardPopup(
                        title: 'Level Complete!',
                        message: '+50 coins earned',
                        icon: Icons.emoji_events_rounded,
                        color: NeonTheme.gold,
                        content: const StarRating(earned: 3, animate: true),
                      ),
                    ),
                  ),
                ),
              if (_spotlightActive)
                Positioned.fill(
                  child: SpotlightOverlay(
                    targetKey: _spotlightTargetKey,
                    title: 'Try this',
                    message:
                        'This is the Primary button — the main action '
                        'on any screen.',
                    color: NeonTheme.cyan,
                    onDismiss: _endTutorial,
                  ),
                ),
              TutorialSequence(
                controller: _tutorialSequenceController,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// FEAT-61: fake "real" analytics provider for the ConsentStateService
/// demo — just counts events it actually received, so the demo can prove
/// ConsentGatedAnalyticsProvider really did (or didn't) forward the call.
class _DemoAnalyticsProvider implements AnalyticsProvider {
  _DemoAnalyticsProvider(this.onEvent);

  final VoidCallback onEvent;

  @override
  void logEvent(String name, [Map<String, Object?>? params]) => onEvent();
}

/// One example: a small caption naming the widget under demo (so the source
/// of a given visual is unambiguous), then the live widget itself — laid out
/// in a [PanelCard], the kit's own generic container.
class _Demo extends StatelessWidget {
  const _Demo({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeonTheme.s16),
      child: PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            child,
          ],
        ),
      ),
    );
  }
}

/// A small pill of HUD content for the AdaptiveGameHud demo (FEAT-52) —
/// stands in for whatever a real game would put in a slot (a score
/// counter, a pause button, ...).
class _HudChip extends StatelessWidget {
  const _HudChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NeonTheme.s16,
          vertical: NeonTheme.s8,
        ),
        child: Text(
          text,
          style: TextStyle(color: NeonTheme.ink, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
