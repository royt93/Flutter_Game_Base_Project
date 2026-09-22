# roy_casual_kit

A Flutter SDK for casual/idle games built on GetX + Flame: local storage,
i18n, audio, haptics, local reminders, theme tokens, an economy/progression
layer, live-ops and remote-content tooling, privacy-aware analytics, and a
candy-styled widget kit — one `RoyCasualKit.initialize(...)` call replaces
hand-rolling `Get.put` calls for every service a casual game typically needs
to build from scratch.

## Screenshots

All from `example/` — light and dark are the same `NeonTheme` tokens, no
call-site changes.

<p align="center">
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/home_light.png" width="180" alt="Home screen, light theme" />
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/home_dark.png" width="180" alt="Home screen, dark theme" />
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/widget_kit_buttons_light.png" width="180" alt="Widget kit: buttons, light theme" />
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/widget_kit_buttons.png" width="180" alt="Widget kit: buttons, dark theme" />
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/widget_kit_interactive.png" width="180" alt="Widget kit: badges and interactive widgets" />
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/widget_kit_overlays.png" width="180" alt="Widget kit: tooltips, bottom sheet, dialogs" />
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/settings_dark.png" width="180" alt="Settings screen, dark theme" />
  <img src="https://raw.githubusercontent.com/royt93/Flutter_Game_Base_Project/main/screenshots/game_demo.png" width="180" alt="Flame game demo with a world-tracked HUD label" />
</p>

## What's in the package

`lib/core/` groups by what the service is for — grep `lib/roy_casual_kit.dart`
or `CLAUDE.md`'s Architecture section for the exhaustive, always-current list;
this is the shape, not a full inventory:

- **Bootstrap** — `RoyCasualKit.initialize(config: ...)` registers every
  requested core service idempotently and never throws; a failing module is
  reported in the result instead of crashing boot.
- **Storage & save data** — `StorageService` (SharedPreferences wrapper with
  a write-behind buffer for hot-path counters), `VersionedJsonStore` +
  `SaveMigrationRegistry` (schema-versioned saves with multi-hop migration),
  `SaveSlotManager`, `save_integrity.dart` (HMAC tamper detection),
  `DisasterRecoverySaveExport`, `CheckpointCoordinator`.
- **Economy & progression** — `EconomyWallet`, `RewardTransactionPipeline`,
  `PlayerProgressionService`, `InventoryService`, `EnergyService`,
  `OfflineProgressionService` (cheat-proof idle earnings, see below),
  `DailyLoginService`, `DailyQuestService`, `AchievementService`,
  `LocalScoreboardService`, `PurchaseLedgerService` + `PurchaseSeam`.
- **Live-ops & remote content** — `RemoteConfigService`, `RemoteContentPack`
  (signed, versioned, asset-fallback-then-fetch), the Remote Schema Compiler
  (`tool/remote_schema_compiler.dart`, compiles a declarative schema into a
  typed, self-contained Dart model), `RemoteKillSwitchController`,
  `SeasonEventService`, `ExperimentBucketingService`.
- **Privacy, analytics & diagnostics** — `ConsentStateService` +
  `ConsentGatedAnalyticsProvider`, `PrivacyAwareAnalyticsSampler`
  (consent-gated, deterministically-sampled, rate-limited),
  `SdkEventSchemaRegistry` (PII redaction before any event ships),
  `SdkHealthReport`, `DiagnosticsExportBundle`, `CrashReporter` seam.
- **Platform seams** (bring your own adapter) — `AnalyticsProvider`,
  `CrashReporter`, `CloudSaveProvider`, `PurchaseSeam`,
  `SecureStorageAdapter`, `RemoteConfigService`, verified against your
  adapter with `PluginAdapterConformanceSuite`.
- **App/session infrastructure** — `AppVersionGateController`, `AppSessionTracker`,
  `RoyLifecycleCoordinator`, `GameSessionController`, `GameTimeController`,
  `ConnectivityCoordinator`, `DeepLinkCommandRouter`,
  `OnboardingCoordinatorService`, `maybeRequestReview` (in-app review helper),
  `ReminderService`, `WakeLockService`, `OfflineOutboxService`, `PersistentCooldownService`,
  `AssetPreloadCoordinator`, `PlatformCapabilityRegistry`, `MemoryWatchdog`.
- **i18n, audio, haptics, theme** — `AppTranslations`/`LocaleService`,
  `AudioManager`, `fireHaptic` + `HapticChoreographer`, `NeonTheme` design
  tokens (light-candy default, neon-dark and color-blind-safe variants).
- **Utilities** (`lib/core/utils/`) — 20+ pure helpers the services above
  delegate to: clock/replay determinism (`ClampedClock`, `TrustedClockService`,
  `SeededRandom`), formatting (`fmtDur`, `fmtNum`, `fitFontSizeForLongestWord`),
  resilience (`AsyncActionGuard`, `RetryPolicy`, `throttled`), and the library
  code behind every `tool/*_check.dart` gate below.
- **Dev/CI tooling** (`tool/`, headless `dart run`, no device needed) —
  accessibility audit, dependency SBOM/security gate, asset-license
  manifest check, API-compatibility gate, performance budget CI,
  deprecated-API removal-schedule gate, pseudo-locale QA harness, consumer-app
  starter generator.

`lib/presentation/widgets/` — the neon widget kit (`NeonButton`,
`NeonDialog`, `NeonAppBar`, `NeonBg`, `NeonAuraLayer`, `AuroraBgLayer`,
`NeonIcon`, `StrokeText`, `PressableScale` — keyboard/gamepad-activatable,
not just touch) plus `lib/presentation/widgets/common/`: a large set of
generic, game-agnostic widgets spanning buttons/interactive, feedback/overlay,
progress/reward, layout/cards, game-specific, and game-feel/juice —
`example/lib/screens/widget_showcase_screen.dart` is the living usage
reference, and the whole set is exported from one barrel,
`lib/presentation/widgets/common/common_widgets.dart`.

## Cookbook

Every core service in `lib/core/` (grouped the same way as the overview
above), with a real, compilable-shape usage snippet each — not just the
class name. `example/lib/screens/cookbook_screen.dart` exercises one call
from most sections below on a live screen; `lib/presentation/widgets/` has
its own living reference in
`example/lib/screens/widget_showcase_screen.dart` instead of being repeated
here. Most services are a `GetxService` — register once (bootstrap module,
or `Get.put(..., permanent: true)`) and read back later via a `X.maybe`
null-safe static accessor or `Get.find<X>()`.

### Storage & save data

#### StorageService
```dart
StorageService.to.setInt('coins', 100);
final coins = StorageService.to.getInt('coins', def: 0);
StorageService.to.setIntBuffered('tapCount', tapCount); // hot-path counter
await StorageService.to.flush();
final backup = StorageService.to.exportAll(); // whole store as JSON
```
Registered by the bootstrap `storage` module.

#### VersionedJsonStore\<T\>
```dart
final store = VersionedJsonStore<PlayerProfile>(
  storage: StorageService.to,
  key: 'player_profile',
  schemaVersion: 2,
  toJson: (p) => p.toJson(),
  fromJson: PlayerProfile.fromJson,
  migrate: (fromVersion, json) => migrationRegistry.migrate(fromVersion, json),
  migrationRegistry: migrationRegistry, // SaveMigrationRegistry, multi-hop chain
);
await store.save(profile);
final loaded = store.load();
```

#### SaveSlotManager
```dart
final slots = SaveSlotManager(maxSlots: 3);
if (slots.canCreateSlot) {
  final slot = slots.createSlot('My Save');
  await slots.setActiveSlot(slot.id);
  final key = slots.keyFor(slot.id, 'player_profile'); // pass to VersionedJsonStore's key
}
```

#### save_integrity.dart
```dart
final signed = signExport(StorageService.to.exportAll(), mySecret);
// ... later, before importAll:
final verified = verifyAndStrip(signed, mySecret); // throws FormatException if tampered
await StorageService.to.importAll(verified);
```
Plain top-level functions, not a class — HMAC tamper detection over
`exportAll()`/`importAll()`.

#### DisasterRecoverySaveExport
```dart
final recovery = DisasterRecoverySaveExport(storage: StorageService.to, slotManager: slots);
final export = recovery.buildExport(slotIds: slots.listSlots().map((s) => s.id).toList(), appVersion: kAppVersion);
final signed = recovery.sign(export.value!, mySecret);
// ... on restore:
final preview = recovery.previewRestore(signed, mySecret);
if (preview.isSuccess) await recovery.applyRestore(preview.value!);
```

#### CheckpointCoordinator
```dart
final checkpoints = CheckpointCoordinator(storage: StorageService.to);
Get.put(checkpoints, permanent: true);
checkpoints.registerParticipant('board', snapshot: () => board.toJson(), restore: (data) => board.load(data));
await checkpoints.requestCheckpoint(); // debounced 2s unless critical: true
if (checkpoints.wasDirtyOnLoad) checkpoints.restoreLatest();
```

### Economy & progression

#### EconomyWallet
```dart
final wallet = EconomyWallet(storage: StorageService.to);
Get.put(wallet, permanent: true);
await wallet.earn(currency: 'coins', amount: 50, transactionId: 'quest_12');
final result = await wallet.trySpend(currency: 'coins', amount: 20, transactionId: 'shop_buy_3');
final coins = wallet.balanceOf('coins');
```

#### RewardTransactionPipeline
```dart
final rewards = RewardTransactionPipeline(wallet: wallet);
Get.put(rewards, permanent: true);
await rewards.grantFromDailyQuest(
  questId: 'daily_win_3',
  periodKey: '2026-09-21',
  lines: [RewardLine(currency: 'coins', amount: 100)],
);
```
Single audited entry point for every reward grant (daily login, daily
quest, purchase, or a raw `grant(...)`) — every call is idempotent on its
`transactionId` and survives a kill mid-grant via `resumePending()`.

#### PlayerProgressionService
```dart
final progression = PlayerProgressionService(storage: StorageService.to, levelCurve: myLevelCurve, pipeline: rewards);
Get.put(progression, permanent: true);
final result = await progression.grantXp(amount: 250, transactionId: 'level_3_clear');
progression.snapshot; // Rx<PlayerProgressionSnapshot>
```

#### InventoryService
```dart
final inventory = InventoryService(storage: StorageService.to, itemCatalog: myItemCatalog, capacity: 40);
Get.put(inventory, permanent: true);
await inventory.grant(lines: [InventoryLine(itemId: 'sword_01', quantity: 1)], transactionId: 'shop_buy_sword');
await inventory.setEquipped(slotId: 0, equipped: true);
```

#### EnergyService — the cheat-proof idle/lives pattern
Idle/incremental games pay out or refill based on "how long was the player
away" — most base kits compute that straight from `DateTime.now()`, so
winding the device clock back and forth farms free energy/rewards
indefinitely. `EnergyService` and `OfflineProgressionService` both read
elapsed time through `nowMsClamped()` (`lib/core/utils/clamped_clock.dart`),
a monotonic clock that never goes backward — a rewind attempt permanently
burns the player's own future time instead of resetting the calculation.
```dart
final energy = EnergyService(maxEnergy: 5, refillInterval: const Duration(minutes: 30));
Get.put(energy, permanent: true);
if (energy.currentEnergy > 0) energy.consumeEnergy();
final wait = energy.timeUntilNextEnergy;
```

#### OfflineProgressionService
```dart
final offline = OfflineProgressionService(maxOfflineCap: const Duration(hours: 8));
Get.put(offline, permanent: true);

// e.g. on app resume, or whenever the player checks in:
final earned = await offline.claim(coinsPerSecond);
if (earned > 0) grantCoins(earned);
```
`maxOfflineCap` caps the payout (an 8h absence still only pays out 8 hours'
worth), and a fresh install never hands out a free payout on its very first
read — the baseline is seeded to "now", not epoch zero.

#### DailyLoginService
```dart
final login = DailyLoginService();
Get.put(login, permanent: true);
if (login.canClaimToday()) {
  final result = login.claimToday(); // day 1..7, wraps back to 1
}
login.currentStreakDay;
```

#### DailyQuestService
```dart
final quests = DailyQuestService();
Get.put(quests, permanent: true);
quests.register('win_3_matches', 3, period: QuestPeriod.daily);
quests.incrementProgress('win_3_matches', 1);
if (quests.isCompleted('win_3_matches') && !quests.isClaimed('win_3_matches')) quests.claim('win_3_matches');
```

#### AchievementService
```dart
final achievements = AchievementService();
Get.put(achievements, permanent: true);
achievements.register('first_win', 1);
achievements.onUnlock.listen((id) => showUnlockToast(id));
achievements.incrementProgress('first_win', 1);
```

#### LocalScoreboardService
```dart
final scoreboard = LocalScoreboardService(capacity: 50);
Get.put(scoreboard, permanent: true);
scoreboard.submitScore('Player1', 9800);
final top10 = scoreboard.topN(10);
final nearMe = scoreboard.entriesAround('Player1', radius: 2); // "you're #47" window
```

#### PurchaseLedgerService + PurchaseSeam
```dart
// 1. Consumer app implements the real store integration:
class MyPurchaseSeam implements PurchaseSeam {
  @override
  Future<bool> buy(String productId) async { /* verify with store/server */ return true; }
  @override
  Future<void> restorePurchases() async {}
  @override
  bool isOwned(String productId) => false;
}
Get.put<PurchaseSeam>(MyPurchaseSeam(), permanent: true);

// 2. After a verified purchase, PurchaseLedgerService just records the result:
final ledger = PurchaseLedgerService();
Get.put(ledger, permanent: true);
if (await PurchaseSeam.maybe!.buy('remove_ads')) ledger.grantPermanent('remove_ads');
```
No `Noop*` default for `PurchaseSeam` on purpose — silently no-op'ing a
purchase would hide a real integration bug.

### Live-ops & remote content

#### RemoteConfigService
```dart
final remoteConfig = RemoteConfigService(assetPath: 'assets/remote_config_defaults.json');
Get.put(remoteConfig, permanent: true);
await remoteConfig.init(); // asset first, then merges a fetchRemote() result — never throws
final rewardMultiplier = remoteConfig.getDouble('reward_multiplier', fallback: 1.0);
```

#### RemoteContentPack\<T\>
```dart
final eventPack = RemoteContentPack<EventDefinition>(
  assetPath: 'assets/season_event_defaults.json',
  schemaVersion: 1,
  fromJson: EventDefinition.fromJson,
  contentSecret: myContentSecret, // signature-verified before it's applied
);
final content = await eventPack.load(); // asset first, background fetch/verify/merge after
await eventPack.refreshed;
```
`tool/remote_schema_compiler.dart` compiles a declarative JSON schema into
this typed `fromJson` model for you:
`dart run tool/remote_schema_compiler.dart --schema=event_schema.json --outDir=lib/generated`.

#### RemoteKillSwitchController
```dart
final killSwitch = RemoteKillSwitchController(remoteConfig: remoteConfig);
Get.put(killSwitch, permanent: true);
killSwitch.runIfEnabled('new_shop_ui', () => showNewShop());
```

#### SeasonEventService
```dart
final seasonEvents = SeasonEventService();
Get.put(seasonEvents, permanent: true);
final window = seasonEvents.currentWindow('winter_2026', length: const Duration(days: 7), cooldown: const Duration(days: 21));
if (window.isActive) showSeasonBanner(window.end);
```

#### ExperimentBucketingService
```dart
final experiments = ExperimentBucketingService();
Get.put(experiments, permanent: true);
final variant = experiments.variantFor('shop_layout_v2', ['control', 'treatment']);
```
Stable per-device bucketing — same device always lands in the same variant,
seeded via `StorageKeys.experimentAnonId` + `fnv1aHash`.

### Privacy, analytics & diagnostics

#### ConsentStateService
```dart
final consent = ConsentStateService(policyVersion: 1);
Get.put(consent, permanent: true);
consent.grant(ConsentCategory.analytics);
if (consent.isGranted(ConsentCategory.analytics)) { /* ... */ }
```
Default-deny: an undecided or stale-policy-version category reads back
`unknown`, never granted.

#### ConsentGatedAnalyticsProvider + PrivacyAwareAnalyticsSampler
```dart
final realProvider = MyAnalyticsAdapter(); // implements AnalyticsProvider
Get.put<AnalyticsProvider>(
  PrivacyAwareAnalyticsSampler(
    ConsentGatedAnalyticsProvider(realProvider),
    defaultSamplingRate: 0.2,
    maxEventsPerWindow: 20,
  ),
  permanent: true,
);
AnalyticsProvider.maybe?.logEvent('level_complete', {'level': 12});
```
Stack the decorators: consent gate → deterministic sampling → rate limit,
one `AnalyticsProvider.logEvent` call site everywhere else in the app.

#### SdkEventSchemaRegistry
```dart
final schemas = SdkEventSchemaRegistry()
  ..register(EventSchema(
    name: 'level_complete',
    version: 1,
    params: {'level': const EventParamSchema(type: EventParamType.int, required: true)},
  ));
final result = schemas.validate('level_complete', {'level': 12}); // default-deny unregistered names
```
PII fields are always redacted before an event ships, regardless of the
inner provider.

#### SdkHealthReport + DiagnosticsExportBundle
```dart
final health = SdkHealthReport()..registerAll(defaultHealthCollectors());
final report = await health.collect(); // {schemaVersion, generatedAtMs, sections}

final bundle = DiagnosticsExportBundle();
final diagnostics = await bundle.build(appVersion: kAppVersion, health: health);
final signed = bundle.sign(diagnostics, mySecret);
```
Each collector in `health.collect()` has its own timeout + try/catch, so one
broken section never blocks the rest of the report — handy to attach to a
support ticket.

#### CrashReporter (seam)
```dart
class MyCrashReporter implements CrashReporter {
  @override
  void recordError(Object error, StackTrace stack, {String? reason}) { /* ship to your vendor */ }
}
Get.put<CrashReporter>(MyCrashReporter(), permanent: true);
```
No `Noop*` default — `dlog()` is debug-only and tree-shaken from release
builds, so a release build with no `CrashReporter` registered has nowhere
for an error to go.

### Platform seams

Bring your own adapter for each of these (no concrete vendor SDK baked into
the package):

```dart
Get.put<AnalyticsProvider>(myAnalyticsAdapter, permanent: true);
Get.put<CrashReporter>(myCrashAdapter, permanent: true);
Get.put<CloudSaveProvider>(myCloudSaveAdapter, permanent: true); // passed to VersionedJsonStore.syncWith
Get.put<PurchaseSeam>(myPurchaseAdapter, permanent: true);
Get.put<SecureStorageAdapter>(mySecureStorageAdapter, permanent: true);
```

Before shipping an adapter, run it through
`PluginAdapterConformanceSuite` — a no-throw / completes-within-timeout /
round-trip checklist so a broken adapter fails a fast local check instead of
a flaky device test:

```dart
final report = await PluginAdapterConformanceSuite.verifyAnalyticsProvider(myAnalyticsAdapter);
expect(report.passed, isTrue, reason: report.failures.join('; '));
```

### App/session infrastructure

#### AppVersionGateController
```dart
final versionGate = AppVersionGateController(remoteConfig: remoteConfig);
Get.put(versionGate, permanent: true);
switch (versionGate.decisionFor(kAppVersion)) {
  case GateDecision.forceUpdate: showForceUpdateDialog();
  case GateDecision.softUpdate: if (versionGate.softPromptDue) showSoftUpdateBanner();
  case GateDecision.maintenance: showMaintenanceScreen();
  case GateDecision.ok: break;
}
```

#### AppSessionTracker
```dart
final sessionTracker = AppSessionTracker();
Get.put(sessionTracker, permanent: true);
sessionTracker.current.sessionId;
sessionTracker.foregroundDuration; // real accumulated foreground time
```

#### RoyLifecycleCoordinator
```dart
final lifecycle = RoyLifecycleCoordinator();
Get.put(lifecycle, permanent: true); // or the bootstrap `lifecycle` module
lifecycle.registerHook('pause_audio', (event) async {
  if (event == RoyLifecycleEvent.background) AudioManager.maybe?.pauseBgm();
});
```
Ordered, isolated dispatcher — one hook throwing/timing out never blocks
the others.

#### GameSessionController + GameTimeController
```dart
final session = GameSessionController(lifecycle: lifecycle);
Get.put(session);
session.markReady();
session.start();
// on win/lose:
session.win();

final gameTime = GameTimeController(session: session);
Get.put(gameTime);
gameTime.tick(deltaSeconds); // Flame Component.update(dt)-shaped
```

#### ConnectivityCoordinator
```dart
final connectivity = ConnectivityCoordinator(signal: myConnectivitySignal, probe: () async => pingServer());
Get.put(connectivity, permanent: true);
connectivity.enqueue(QueuedTask(idempotencyKey: 'sync_save', priority: 1, run: () => syncSave()));
connectivity.stateStream.listen((state) => updateOfflineBanner(state));
```

#### DeepLinkCommandRouter
```dart
final deepLinks = DeepLinkCommandRouter(routes: [
  DeepLinkRoute(commandType: 'open_shop', scheme: 'myapp', pathSegments: ['shop']),
]);
Get.put(deepLinks, permanent: true);
deepLinks.registerHandler('open_shop', (command) async => Get.toNamed('/shop'));
deepLinks.markReady(); // drains any link that arrived before this call
```

#### OnboardingCoordinatorService
```dart
final onboarding = OnboardingCoordinatorService();
Get.put(onboarding, permanent: true);
onboarding.registerFlow('first_launch_tutorial', priority: 10);
onboarding.registerFlow('shop_spotlight', priority: 5);
final next = onboarding.nextEligibleFlow(); // highest-priority unseen, or null
if (next != null) { showFlow(next); onboarding.markFlowSeen(next); }
```

#### maybeRequestReview
```dart
await maybeRequestReview(
  recentWinStreak: playerWinStreak,
  showReview: () => InAppReview.instance.requestReview(),
  minWinStreak: 3,
);
```
The classic casual-game pattern: prompt right after a happy moment, not too
often — a single platform-neutral function, no store-review SDK baked in.

#### ReminderService
```dart
final reminders = ReminderService();
Get.put(reminders, permanent: true); // or the bootstrap `reminders` module
await reminders.scheduleNext(delay: const Duration(hours: 24), title: 'Come back!', body: 'Your energy is full.');
```

#### WakeLockService
```dart
final wakeLock = WakeLockService(); // or the bootstrap `wakeLock` module
Get.put(wakeLock, permanent: true);
await wakeLock.init(); // restores the saved on/off preference and applies it
await wakeLock.setEnabled(false); // e.g. a settings toggle
```
Keeps the screen from auto-locking while `enabled` (defaults to `true` —
opt-out, matching the classic casual-game expectation) — persists the
choice via `StorageKeys.wakeLockEnabled` so a consumer app's own settings
screen can expose the toggle instead of the kit forcing the screen awake
unconditionally.

#### OfflineOutboxService
```dart
final outbox = OfflineOutboxService(storage: StorageService.to, uploader: (payload, key) => myApi.sync(payload, key));
Get.put(outbox, permanent: true);
outbox.enqueue(idempotencyKey: 'score_sync_42', payload: {'score': 9800});
await outbox.drain(); // priority-ordered sync attempt, retries with backoff
```

#### PersistentCooldownService
```dart
final cooldowns = PersistentCooldownService();
Get.put(cooldowns, permanent: true);
cooldowns.start('free_chest', const Duration(hours: 4));
cooldowns.remainingOf('free_chest');
```

#### AssetPreloadCoordinator
```dart
final preloader = AssetPreloadCoordinator(loader: (item) => precacheImage(AssetImage(item.path), context));
Get.put(preloader, permanent: true);
await preloader.preload(myLevelManifest);
preloader.progress; // Rx<double> 0.0–1.0
```

#### PlatformCapabilityRegistry
```dart
final capabilities = PlatformCapabilityRegistry();
Get.put(capabilities, permanent: true);
capabilities.withFallback(
  supported: capabilities.snapshot.supportsHaptics,
  ifSupported: () => fireHaptic(HapticLevel.medium),
  fallback: () {},
);
```

#### MemoryWatchdog (debug builds only, no-op in release)
```dart
final id = MemoryWatchdog.track(WatchdogKind.subscription, owner: 'ShopController', label: 'priceStream');
// ... on dispose:
MemoryWatchdog.release(id);
MemoryWatchdog.orphans(minAge: const Duration(minutes: 5)); // leak candidates
```

### i18n, audio, haptics, theme

#### AppTranslations + LocaleService
```dart
GetMaterialApp(translations: AppTranslations(), locale: LocaleService.maybe?.current.value, /* ... */);
final locale = LocaleService(StorageService.to);
Get.put(locale, permanent: true); // or the bootstrap `locale` module
await locale.change(const Locale('vi'));
```
New keys go into every locale map in `AppTranslations` —
`test/core/app_translations_test.dart` enforces key parity.

#### AudioManager
```dart
final audio = AudioManager(); // or the bootstrap `audio` module
Get.put(audio, permanent: true);
await audio.init();
audio.startBgm();
await audio.playSfx('coin.mp3', volume: 0.8);
audio.toggleMute();
```
`AudioManager.maybe` is the null-safe accessor for call sites that may run
before/without audio registered (e.g. widget tests).

#### fireHaptic + HapticChoreographer
```dart
fireHaptic(HapticLevel.medium); // gated on StorageKeys.hapticsEnabled/hapticSoftMode

final choreographer = HapticChoreographer();
choreographer.play(HapticPattern.combo); // ordered pulses with per-step delay
```
Every `HapticFeedback.*` call site in a consumer app should go through
`fireHaptic`, not the platform API directly.

#### NeonTheme
```dart
NeonTheme.dark = true; // flip to the neon-dark palette, persist the flag yourself
NeonTheme.colorBlindSafe = true;
Container(decoration: BoxDecoration(color: NeonTheme.card, boxShadow: NeonTheme.glow(NeonTheme.gemColors.first)));
```
Same token getters (`ink`, `card`, `glow(...)`, ...) resolve to different
colors depending on the flags — no call site needs to change.

### Utilities (`lib/core/utils/`)

Pure, dependency-light helpers the services above delegate to — reach for
these directly when a service is more than what a call site needs.

- `nowMsClamped()` / `todayEpochDayClamped()` (`clamped_clock.dart`) — monotonic never-rewinds-back clock.
- `TrustedClockService` (`trusted_clock.dart`) — stricter wall-clock-vs-monotonic drift check.
- `fmtDur(d)` / `durationToLocalMidnight(d)` / `fmtNum(n)` (`format.dart`) — mm:ss, countdown, locale-aware thousands separator.
- `fitFontSizeForLongestWord(...)` (`label_fit.dart`) — shrinks a label until every word fits, guards mid-word line breaks.
- `asIntOr(json['x'], 0)` / `asStringOr(...)` / `asDoubleOr(...)` (`safe_json.dart`) — tolerant JSON field coercion.
- `throttled(onTap, window: const Duration(milliseconds: 500))` (`throttle.dart`) — drops rapid repeat calls (double-tap/spam guard).
- `weightedRandomPick(myLootTable)` (`weighted_random_pick.dart`) — one weighted pick (loot tables, reward rarities).
- `fnv1aHash(input)` (`fnv1a.dart`) — deterministic string hash, the seed source for experiment bucketing.
- `SeededRandom` / `CompiledWeightedTable<T>` / `SeededRandomService` (`seeded_random.dart`) — snapshot/resume-capable RNG for deterministic replay.
- `AsyncActionGuard` (`async_action_guard.dart`) — ignore a call while a previous one from the same guard is still in flight (fast-double-tap guard for async actions).
- `RetryPolicy` / `RetryExecutor` (`retry_policy.dart`) — exponential-backoff-with-jitter retry loop.
- `SaveMigrationRegistry` (`save_migration_registry.dart`) — validated multi-hop save-schema migration chain, see `VersionedJsonStore` above.
- `SdkResult<T>` / `SdkSuccess` / `SdkFailure` (`sdk_result.dart`) — the typed success/failure convention most services above return.
- `ObjectPool<T>` (`object_pool.dart`) — generic acquire/release pool for per-frame particle/effect allocation.
- `pseudoLocalize(...)` / `PseudoLocaleTranslations` (`pseudo_locale.dart`) — accents+pads strings to surface hardcoded/untranslated text; wired into `example/lib/screens/settings_screen.dart`'s locale toggle for a live QA pass.
- `validateNeonThemeContrast()` / `contrastRatio(...)` (`theme_contrast_validator.dart`) — WCAG-style contrast checks over `NeonTheme` color pairs.
- `scanAccessibility(...)` (`accessibility_audit.dart`), `auditDependencies(...)` (`dependency_sbom.dart`), `validateAssetLicenses(...)` (`asset_license_manifest.dart`), `DeprecationRegistry` (`deprecation_registry.dart`), `checkPerformanceBudgets(...)` (`performance_budget.dart`), `generateModelSource(...)` (`remote_schema_compiler.dart`) — the library code behind the `tool/*_check.dart` CLI gates below.
- `regenEnergy(...)` / `offlineEarnings(...)` (`economy_math.dart`) — the pure formulas `EnergyService`/`OfflineProgressionService` delegate to, also used by `tool/economy_sim.dart` so the balancing simulator can never silently drift from the real math.

### Dev/CI tooling (`tool/`, headless `dart run`, no device needed)

```bash
dart run tool/api_compatibility.dart check          # public-export diff gate
dart run tool/accessibility_audit_check.dart         # reduced-motion / tap-target / RTL scan
dart run tool/dependency_sbom_check.dart             # SBOM + license/advisory gate
dart run tool/asset_license_check.dart               # every runtime asset has a LICENSES.json entry
dart run tool/performance_budget_check.dart check    # frame/allocation budget vs committed baseline
dart run tool/deprecation_check.dart                 # fails once a @Deprecated API is past its removal version
dart run tool/economy_sim.dart --days=30             # headless economy/balancing simulator
dart run tool/object_pool_benchmark.dart             # pooled-vs-unpooled allocation benchmark
dart run tool/remote_schema_compiler.dart --schema=event_schema.json --outDir=lib/generated
dart run tool/create_consumer_app.dart --name=my_game --org=com.example
```
`accessibility_audit_check`, `dependency_sbom_check`, `asset_license_check`,
`performance_budget_check`, and `deprecation_check` are wired into CI's
`quality-gate` job (see `.github/workflows/ci.yml`), scoped to only run
when `lib/**`/`tool/**` change. `performance_budget_check`'s `realDevice`
metric only gets a fresh number when run with `--device=<id>`; otherwise it
falls back to the committed baseline — see the Performance section below
for how that baseline gets refreshed automatically.

## Performance

`tool/performance_budget_check.dart` tracks two kinds of metric: a
`hostHeadless` one (re-measured fresh on every `check` run, reproducible on
any machine) and a `realDevice` one (real wall-clock boot time, only
re-measured when a device is attached — see `--device=` above). A weekly
GitHub Actions job (`.github/workflows/benchmark.yml`, free — this repo is
public and runs on `ubuntu-latest`) boots a KVM-accelerated Android
emulator, re-measures both, and opens a PR refreshing the numbers below.

<!-- PERF_BENCHMARK_START -->
| Metric | Value | Source | Recorded |
|---|---|---|---|
| Example App Boot Wall Ms | 32318 ms | realDevice | 2026-09-20 |
| Example App Boot Wall Ms Emulator | 338690 ms | realDevice | 2026-09-22 |
| Object Pool Allocation Reduction Percent | 97.5% | hostHeadless | 2026-09-22 |
| Object Pool Pooled Elapsed Us | 22327 us | hostHeadless | 2026-09-22 |
<!-- PERF_BENCHMARK_END -->

## Install

```bash
flutter pub add roy_casual_kit
```

For working against an unreleased local change, depend on it directly instead:

```yaml
dependencies:
  roy_casual_kit:
    path: ../roy_casual_kit # or: git: { url: ..., ref: main }
```

## Usage

Bootstrap the services a game needs once at startup, instead of hand-rolling
`Get.put` calls for each one:

```dart
await RoyCasualKit.initialize(
  config: RoyCasualKitConfig(
    modules: {
      RoyCasualKitModule.storage,
      RoyCasualKitModule.locale,
      RoyCasualKitModule.audio,
      RoyCasualKitModule.lifecycle,
    },
  ),
);
```

A module that fails to register is reported in the returned result instead
of crashing boot — see `RoyCasualKitResult`/`RoyCasualKitStatus`.

```dart
import 'package:flutter/material.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonButton(
      label: 'Play',
      variant: CommonButtonVariant.primary,
      onTap: () => debugPrint('tapped'),
    );
  }
}
```

The same entrypoint exposes supported core services, Flame starter APIs and
the complete widget kit. Existing deep imports under `core/` and
`presentation/` remain available for advanced use, but new consumer code
should migrate to the entrypoint so the supported API surface is explicit.

For consumer tests, `RoyCasualKitTestFixture` provides deterministic in-memory
storage and `RoyCasualKitContractTestKit.verifyBootstrap` checks module
registration, error-free initialization and idempotent repeated setup without
network or vendor SDK dependencies.

For how to actually use each service once it's registered — real,
compilable-shape snippets for all of `lib/core/`, grouped the same way as
the overview above — see the [Cookbook](#cookbook) section.

## See it live

`example/` is a separate, full Flutter app (its own `pubspec.yaml`,
`android/`, `ios/`) — deliberately not a trimmed-down toy demo. Its
`lib/main.dart` wires up real usage of most modules covered above
(bootstrap, lifecycle, deep links, audio, reminders, theming); reading it
directly is the fastest way to see the actual integration pattern, not just
a single-widget snippet. See `example/README.md` for a tour of which file
covers what.

```bash
cd example && flutter run
```

## Commands

```bash
# From the package root
flutter analyze
flutter test --exclude-tags slow

# From example/ — the demo app has its own test/analyze surface
cd example
flutter analyze
flutter test --exclude-tags slow
```

## History

This repo used to be a full match-3 puzzle game, "Pop Star Blast" (see git
history). It was first stripped down to a reusable app base — core services
plus a small widget kit, with `lib/logic/`, `lib/data/`, and `lib/game/`
emptied out — documented in
`docs/superpowers/plans/2026-09-05-strip-to-base-game.md`. It was then
reshaped again from an app into this pub.dev package: the reusable code
stayed at the repo root as `lib/`, and everything app-specific (entry point,
demo screens, `android/`, `ios/`) moved into a separate `example/` app that
depends on the package via a `path:` dependency — documented in
`docs/superpowers/plans/2026-09-05-convert-to-pub-package.md`.

## License

MIT — see `LICENSE`.
