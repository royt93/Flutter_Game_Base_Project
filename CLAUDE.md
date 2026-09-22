# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**roy_casual_kit** — a Flutter *package* (not an app): local storage, i18n,
audio, haptics, local reminders, theme tokens, a small Flame integration
point, and a candy-styled casual-game widget kit, built on GetX. Package
name: `roy_casual_kit`. Font: Baloo2.

The repo has two parts:
- Root `lib/` — the package itself: core services (`lib/core/`), widgets
  (`lib/presentation/widgets/`), and one Flame game shell
  (`lib/presentation/game/roy_game.dart`). No `main.dart`, no screens, no
  `android/`/`ios/` at the root.
- `example/` — a **separate** Flutter app with its own `pubspec.yaml`,
  `android/`, `ios/`, and `lib/main.dart` + 4 screens (`HomeScreen`,
  `SettingsScreen`, `WidgetShowcaseScreen`, `GameDemoScreen`). It depends on
  the root package via `path: ../` in `example/pubspec.yaml`.

Rule of thumb for new work: a new reusable core service or widget goes in
root `lib/`; a new demo screen, app-specific behavior, or anything that only
exercises the kit goes in `example/lib/`.

This repo was previously a full match-3 game ("Pop Star Blast") and, before
that, a lean app-shaped "base game" template — see `lib/logic/`, `lib/data/`,
`lib/game/`, and a `GameController` do **not** exist here; don't assume any
of that survived. History (both reshapes) is in git and in
`docs/superpowers/plans/2026-09-05-strip-to-base-game.md` and
`docs/superpowers/plans/2026-09-05-convert-to-pub-package.md`.

## Commands

```bash
# Package root
flutter analyze
flutter test --exclude-tags slow
flutter test test/core/storage_service_test.dart          # single file
flutter test test/core/storage_service_test.dart --plain-name "some test name"
dart run tool/api_compatibility.dart check                # public-API diff gate (see below)
dart run tool/api_compatibility.dart snapshot              # regenerate tool/api_snapshot.json after an intentional export change
dart pub publish --dry-run                                 # publish-hygiene gate

# example/ app — its own analyze/test surface, run from example/
cd example
flutter analyze
flutter test --exclude-tags slow
flutter run -d <device-id>
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true   # device smoke test
```

`dart_test.yaml` (root) declares a `slow` tag for future heavy device-driven
integration tests; nothing currently carries that tag, so
`--exclude-tags slow` is a no-op today at the root — keep tagging that way if
a new integration test ends up slow. CI (`.github/workflows/ci.yml`) runs,
in order: the API-compatibility check, `flutter analyze`, `flutter test`,
`dart pub publish --dry-run`, then repeats analyze+test with
`working-directory: example`. A change that adds/removes/renames a public
export in `lib/roy_casual_kit.dart` will fail CI until you run the
`tool/api_compatibility.dart snapshot` command above and commit the updated
`tool/api_snapshot.json`.

Root tests mirror `lib/`: `test/core` (+ `test/core/utils`), `test/widget`
(+ `test/widget/common`, `test/widget/goldens`), `test/presentation/game`
(Flame `GameWidget` smoke test), `test/tool` (cross-checks the headless
`tool/economy_sim.dart` simulator against the real services). `example/test/`
holds widget tests for the demo screens; `example/integration_test/` has the
device boot test.

## Architecture

### 1. Bootstrap (`lib/core/kit_bootstrap.dart`)
`RoyCasualKit.initialize(config: RoyCasualKitConfig(modules: {...}))` is the
one entry point a consumer app calls at startup instead of hand-rolling
`Get.put` calls. `RoyCasualKitModule` is an enum of optional modules
(`storage`, `locale`, `audio`, `reminders`, `performance`, `lifecycle`,
`wakeLock`);
`initialize` registers each requested module's `GetxService` idempotently
(skips if already registered — safe to call from a test that also does its
own setup) and never throws: a module whose registration throws is recorded
in the returned `RoyCasualKitResult.errors` and the overall status becomes
`RoyCasualKitStatus.degraded` rather than crashing boot. `resetForTesting()`
tears down only SDK-owned registrations (leaves consumer-registered services
alone) — call it between tests that each call `initialize`. When adding a
new core `GetxService` that a consumer must register, prefer wiring it into
this module enum over telling every consumer to call `Get.put` themselves.

### 2. Core services (`lib/core/`, `lib/core/utils/`)
- **`storage_service.dart`** — `StorageService` (a `GetxService` wrapping `SharedPreferences`, singleton via `StorageService.to`) and `StorageKeys` (18 constants — grep the class for the exact list rather than trusting a count here, it grows often). Never use string literals for prefs keys — add a new named constant instead. Falls back to an in-memory map if `SharedPreferences.getInstance()` throws at boot, so a broken-storage device doesn't crash white-screen. Also has a write-behind buffer (`setIntBuffered`/`setStringBuffered` + `flush()`) for hot-path counters where a missed write on kill is acceptable — real transactions (purchases, resets) must use the unbuffered `setInt`/`setString` so they're never lost. `exportAll()`/`importAll()` round-trip the whole store as one JSON blob (used by `save_integrity.dart` and the example's `BackupRestorePanel`).
- **`app_translations.dart`** — `AppTranslations`, 2 seed locales (`en`/`vi`), 11 base keys. Copy this file's one-`Map`-per-locale pattern when a consumer needs more languages/keys.
- **`locale_service.dart`** — `LocaleService`, persists the chosen locale via `StorageKeys.localeCode` and falls back to device locale, then `AppTranslations.fallback`. Depends on `AppTranslations.codeOf(Locale)` to round-trip a locale to/from its stored string.
- **`audio_manager.dart`** — `AudioManager`, one background track + mute, persists mute via `StorageKeys.audioMuted`. `AudioManager.maybe` is the null-safe accessor for call sites that may run before/without audio registered (e.g. widget tests).
- **`haptics.dart`** / **`haptic_choreographer.dart`** — `fireHaptic(HapticLevel)` is gated on `StorageKeys.hapticsEnabled`/`hapticSoftMode`; every `HapticFeedback.*` call in a consumer app should go through it, not the platform API directly. `HapticChoreographer` sequences a `HapticPattern` (ordered pulses with per-step delay) on top of that single-shot primitive, for combo/win feedback that's more than one buzz.
- **`neon_theme.dart`** — `NeonTheme` design tokens: `dark` flag (bright-casual light theme by default, flip for a neon-dark palette), `colorBlindSafe` flag (persisted via `StorageKeys.colorBlindSafe`), spacing constants, candy color palette, `glow(...)`/`drop(...)` shadow helpers.
- **`reminder_service.dart`** — `ReminderService`, one scheduled local notification. A consumer app that needs several reminder kinds should extend this, not add branches here.
- **`share_helper.dart`** — `shareText`/`shareBoardImage`/`shareScoreCard`/`shareJourneyCard`, one `share_plus` pipeline for text or `RepaintBoundary`-captured PNGs.
- **`app_info.dart`** — `kAppName`, `kCopyright`, `kAppVersion`/`kAppBuildNumber` (auto-loaded from the consuming app's `pubspec.yaml` via `package_info_plus`), `kPackageName` (same, read from the platform package id).
- **`runtime_flags.dart`** — `isE2eTest` (`--dart-define=E2E_TEST=true`), used to skip audio init during automated device tests so `audioplayers`' frame callback doesn't outlive `tearDown`.
- **`debug_log.dart`** — `dlog('message')`, no-op in release builds (tree-shaken), all output prefixed `roy93~` for logcat filtering.
- **`utils/clamped_clock.dart`** — `nowMsClamped()`/`todayEpochDayClamped()`, a monotonic (never-goes-backward) clock built on `StorageKeys.maxMsSeen`/`maxEpochDaySeen`, for any time-gated reward system that shouldn't be exploitable by turning the device clock back. `StorageKeys.trustedClockBaselineMs`/`trustedClockPrevWallMs`/`trustedClockPrevMonotonicMs` back a stricter wall-clock-vs-monotonic drift check layered on top of the same idea.
- **`utils/format.dart`** — `fmtDur` (mm:ss), `durationToLocalMidnight`, `fmtNum` (locale-aware thousands separator via `intl`).
- **`utils/label_fit.dart`** — `fitFontSizeForLongestWord`, shrinks a label's font size until every individual word (not the whole string) fits a max width — guards against mid-word line breaks in long-word languages (German, etc.).
- **`utils/safe_json.dart`** — `asIntOr`/`asStringOr`/`asDoubleOr`, tolerant type-coercing readers for a decoded JSON map (e.g. a `VersionedJsonStore` payload) where a field might be the wrong type or missing.
- **`utils/throttle.dart`** — `throttled(VoidCallback, {Duration window})`, wraps a callback so rapid repeat calls (double-tap, spam) within `window` are dropped after the first.
- **`utils/weighted_random_pick.dart`** — `weightedRandomPick<T>(...)`, picks one item from a weighted list (loot tables, reward rarities).
- **`utils/fnv1a.dart`** — a pure FNV-1a string hash; the deterministic seed source for `ExperimentBucketingService` and `SeededRandom`-style replay/A-B assignment, so the same input string always buckets the same way across runs and platforms.
- **`utils/economy_math.dart`** — the pure regen/earnings formulas `EnergyService` and `OfflineProgressionService` actually delegate to. `tool/economy_sim.dart` (a headless CLI simulator, no Flutter dependency) calls these same functions so the balancing tool can never silently drift out of sync with the real game math — see `test/tool/economy_sim_test.dart` for the cross-check.
- **`utils/async_action_guard.dart`** — a reusable "ignore this call while a previous one is still in flight" guard, for buttons/actions that must not double-fire from a fast double-tap while awaiting an async result.
- **`utils/seeded_random.dart`** — `SeededRandom` (a `Random` implementation whose stream can be snapshotted/resumed via `RandomSnapshot`/`fromSnapshot`, for deterministic replay), `CompiledWeightedTable<T>` (a precompiled version of `weightedRandomPick` for a table sampled repeatedly), `SeededRandomService` (a `GetxService` wrapper). Avoids `dart:math`'s `Random`'s lack of a portable seek/snapshot story.
- **`utils/trusted_clock.dart`** — `TrustedClockService`/`ClockSample`/`ClockJudgement`, a stricter wall-clock-vs-monotonic drift check (backed by `StorageKeys.trustedClockBaselineMs`/`trustedClockPrevWallMs`/`trustedClockPrevMonotonicMs`) for time-gated systems that need more than `ClampedClock`'s simple never-goes-backward guarantee.
- **`utils/save_migration_registry.dart`** — `SaveMigrationRegistry`, an immutable, validated multi-hop save-schema migration chain (`SaveMigrationStep`, throws `SaveMigrationException` on a broken/missing hop) — for a `VersionedJsonStore` migration path with more than one version jump.
- **`utils/sdk_result.dart`** — `SdkResult<T>` (a sealed success/failure result type) and `SdkErrorKind` (validation/storage/platform/network/conflict/unknown), a shared typed-error convention for kit APIs that can fail in more than one way instead of throwing/returning null.
- **`offline_progression_service.dart`** — `OfflineProgressionService`, idle/offline earnings (`min(elapsed, maxOfflineCap) * rate`) since the last claim, built on `nowMsClamped()` so winding the device clock back can't re-farm the payout. No "watch an ad to double" flow — that's layered on top of `claim()` by the consumer app.
- **`versioned_json_store.dart`** — `VersionedJsonStore<T>`, a thin versioned-JSON-object store on top of `StorageService`'s plain key/value strings, for save data with real shape (player profile, level progress) that must survive a schema change between game versions — caller supplies `toJson`/`fromJson`/a `migrate` step, and (optionally) a `CloudSaveProvider` to `syncWith`.
- **`save_slot_manager.dart`** — `SaveSlotManager`, bookkeeping (name, timestamp, slot id) for multiple save slots on top of `VersionedJsonStore`-style saves; it never sees or owns the actual player-profile payload inside a slot, only metadata about the slot itself.
- **`save_integrity.dart`** — an HMAC checksum layer over `StorageService.exportAll()`/`importAll()`: sign a save on export, verify on import, so a consuming game can detect a hand-edited save (e.g. an externally bumped coin count).
- **`performance_tier_service.dart`** — `PerformanceTierService`, a pure FPS tracker (no `SchedulerBinding` dependency, unit-testable with synthetic frame durations) with hysteresis (separate downgrade/upgrade FPS thresholds) that decorative shader/ticker layers (`AuroraBgLayer`/`NeonAuraLayer`, via `ShaderTickerLayerState`) check to decide whether to keep animating.
- **`daily_login_service.dart`** — `DailyLoginService`, a repeating 7-day login-streak cycle (`claimToday()`), day 1..7 then wraps back to day 1.
- **`daily_quest_service.dart`** — `DailyQuestService`, per-period quest progress (`QuestPeriod`) keyed by a `periodKey`; a persisted quest record whose `periodKey` no longer matches the quest's *current* period key is treated as stale/not-started rather than carried over, so quests naturally reset when their period rolls.
- **`energy_service.dart`** — `EnergyService`, a refill-over-time energy/lives system (Candy Crush-style hearts) — current energy is computed lazily from elapsed time via `nowMsClamped()`, never `DateTime.now()` directly, for the same anti-clock-rewind reason as `ClampedClock`.
- **`economy_wallet.dart`** — `EconomyWallet` (a `GetxService`), the soft/hard-currency balance ledger for a game built on this kit.
- **`achievement_service.dart`** — `AchievementService` (a `GetxService`), local achievement/badge progress tracking — no Game Center/Play Games dependency.
- **`local_scoreboard_service.dart`** — `LocalScoreboardService`, an on-device high-score list with fully deterministic ordering (explicit tie-break, doesn't rely on `List.sort`'s lack of a stability guarantee).
- **`purchase_ledger_service.dart`** — `PurchaseLedgerService`, persists the resulting balance/ownership *after* a consumer app's own `PurchaseSeam` adapter has already verified a purchase through the real store/server — this service has no store integration of its own, it's the local record-keeping layer underneath one.
- **`season_event_service.dart`** — `SeasonEventService` tracks a live-ops event's active time window (`SeasonEventWindow`/`currentWindow()`), separate from the repeating daily-login cycle above.
- **`onboarding_coordinator_service.dart`** — `OnboardingCoordinatorService`, tracks "seen" state across a game's several onboarding moments (first-ever launch, a post-update feature spotlight, a first-visit shop tip) in one place instead of ad hoc flags scattered per feature.
- **`experiment_bucketing_service.dart`** — `ExperimentBucketingService`, stable A/B-test variant assignment on top of `RemoteConfigService`, seeded via `StorageKeys.experimentAnonId` + `utils/fnv1a.dart` so a given device always lands in the same bucket.
- **`remote_content_pack.dart`** — a typed, signed remote content slot for live-ops content (a level, an event definition) pushed after install.
- **`replay_recorder.dart`** — `ReplayRecorder`, records input/decision events with a monotonic offset from `start()` (never wall-clock), so a recorded replay doesn't depend on real-world timing to reproduce.
- **`lifecycle_coordinator.dart`** — `RoyLifecycleCoordinator`, an ordered, isolated app-lifecycle dispatcher shared by SDK modules and the consumer app, registered via the `lifecycle` bootstrap module.
- **`game_session_controller.dart`** — `GameSessionController` (a `GetxController`), the single source of truth for one game session's phase (`GameSessionPhase`: loading/ready/playing/paused/won/lost) and pause reason (`GamePauseReason`).
- **`consumer_contract_test_kit.dart`** — a deterministic, vendor-neutral test fixture for consumer contract tests: uses `StorageService`'s in-memory fallback and never touches network, audio, notifications, or a platform channel. Reach for this instead of hand-building fakes when testing that a consumer app integrates correctly with the kit's public surface.
- **`in_app_review_helper.dart`** — `InAppReviewHelper`, decision logic for "should we ask for a store review right now" (the classic casual-game pattern: prompt right after a happy moment, not too often) — platform-neutral, no concrete review-prompt SDK baked in.
- **`wake_lock_service.dart`** — `WakeLockService`, wraps `wakelock_plus` with a persisted on/off preference (`StorageKeys.wakeLockEnabled`, default `true`) instead of a consumer app unconditionally forcing the screen awake — registered via the `wakeLock` bootstrap module.
- **Seams (platform-neutral, no concrete SDK dependency; a consumer app implements and registers its own adapter via `Get.put<X>(myAdapter, permanent: true)`)** — `crash_reporter.dart` (`CrashReporter`, since `dlog()` is debug-only/tree-shaken from release builds), `analytics_provider.dart` (`AnalyticsProvider` + a `NoopAnalyticsProvider` default), `cloud_save_provider.dart` (`CloudSaveProvider`, passed to `VersionedJsonStore.syncWith`), `remote_config_service.dart` (`RemoteConfigService`, feature-flag/remote-config seam), `purchase_seam.dart` (`PurchaseSeam` — minimal `buy`/`restorePurchases`/`isOwned` IAP seam, no `Noop*` default on purpose since silently no-op'ing a purchase would hide a real integration bug).

### 3. Widgets (`lib/presentation/widgets/`)
- **Loose files** (not in `common/`) — `NeonButton`, `NeonDialog`, `NeonAppBar`, `NeonBg`, `NeonAuraLayer`, `AuroraBgLayer`, `NeonIcon`, `StrokeText`, `PressableScale`, `ShaderTickerLayer` (the mixin `AuroraBgLayer`/`NeonAuraLayer` use to check `PerformanceTierService` before animating), `FlameTrackedOverlay` (positions a normal Flutter widget over a world-space point inside a Flame `GameWidget`, re-read every frame), `DebugQaOverlay` (wrap the app root with it; adds a dev-only overlay with tabs including replay inspection via `ReplayRecorder`).
- **`common/`** — ~47 generic, game-agnostic widgets plus a barrel (`common_widgets.dart`) exporting all of them in one import. Don't trust a hardcoded list or count here to stay current — `ls lib/presentation/widgets/common/` or the barrel file is the source of truth, and `example/lib/screens/widget_showcase_screen.dart` is the living usage reference (check it before guessing a constructor signature). Broad categories: buttons/interactive (`CommonButton`, `ToggleSwitch`, `SegmentedTabBar`, `SoundToggleFab`, `CandyTextField`, ...), feedback/overlay (`LoadingOverlay`, `ToastBanner`, `ConfirmDialog`, `ConfettiOverlay`, `SpotlightOverlay`, `TutorialSequence`, ...), progress/reward (`ProgressBarStars`, `StarRating`, `CurrencyCounter`, `RewardPopup`, `EnergyBar`, `DailyLoginCalendarWidget`, `WheelSpinner`, ...), layout/cards (`PanelCard`, `ShopItemCard`, `VictoryCardTemplate` — renders a shareable QR code via the `qr_flutter` dependency, `GameOverCardTemplate`, `LeaderboardList`, ...), game-specific (`LevelSelectGrid`, `QuestBoardPanel`), game-feel/juice (`SquashStretch`, `ScreenShake`, `ComboHeatBackground`), plus utility widgets like `BackupRestorePanel` (wraps `StorageService.exportAll`/`importAll`) and `AchievementUnlockListener`. `CommonButton` is a superset of `NeonButton` (more variants) — `NeonButton` stays as-is, this doesn't replace it.

### 4. Flame integration (`lib/presentation/game/roy_game.dart`)
`RoyGame` is a minimal `FlameGame` proving the `flame` dependency's
`FlameGame`/`Component`/`GameWidget` wiring actually works end-to-end in this
package (it was declared but unexercised before — see `test/presentation/game/roy_game_test.dart`).
It is not a real game; `example/lib/screens/game_demo_screen.dart` is the
reference for embedding it inside a real widget tree (with `FlameTrackedOverlay`
for HUD elements positioned in world space).

### 5. `example/` app
A standalone Flutter app depending on the root package via `path: ../`.
`example/lib/main.dart` calls `RoyCasualKit.initialize(...)` (see Bootstrap
above) with the `storage`/`locale`/`lifecycle`/`reminders` modules plus
`audio` unless `withAudio: false` (e.g. under `isE2eTest`), registers
`ReplayRecorder` directly (a pure in-memory debug aid, safe under E2E too),
sets `NeonTheme.dark`/`NeonTheme.colorBlindSafe` from storage, wraps the root
in `DebugQaOverlay`, and boots `GetMaterialApp`. Screens: `HomeScreen`
(title + navigation), `SettingsScreen` (locale dropdown + audio mute
toggle), `WidgetShowcaseScreen` (demos every `common/` widget, section by
section), `GameDemoScreen` (embeds `RoyGame` inside a `GameWidget`). Any new
demo screen or app-specific behavior belongs here, not in the package `lib/`.

## Key Conventions

### Storage
See `storage_service.dart` above — `StorageKeys` holds every persisted key, `StorageService.to` is the singleton getter. Anything storing an id from a const table (skins, unlocks, etc.) must re-validate on load rather than trust a stale id.

### Bootstrap
Prefer `RoyCasualKit.initialize(config: ...)` over manual `Get.put` calls when a consumer app (or a test) needs to stand up kit services — see Architecture §1. Call `RoyCasualKit.resetForTesting()` between tests that each call `initialize`.

### Dialog pattern
`NeonDialog.show(...)`/`NeonDialog.overlay(panel: ...)` render dialogs as in-tree overlays rather than pushing a route. This exists because a full-screen Flame `GameWidget` (this package depends on `flame` for exactly that use case — see Architecture §4) makes `Get.dialog`/`showDialog` no-ops: nothing can push a route over it. Prefer the overlay pattern for any dialog from the start so it isn't a rewrite later.

### i18n
Translations live in `AppTranslations` (`lib/core/app_translations.dart`), 2 supported locales (`AppTranslations.supported`: `en`, `vi`). New keys go into both locale maps — `test/core/app_translations_test.dart` enforces key parity between locales, so a key added to only one map fails the suite immediately.

### Debug Logging
Use `dlog('message')` from `lib/core/debug_log.dart`. No-ops in release builds. All debug prints are prefixed `roy93~` for easy logcat filtering.

### Theme
`NeonTheme` (`lib/core/neon_theme.dart`) is a bright-casual (Candy-Crush-style) look by default: light candy-sky gradient background, tokens `ink`/`inkSoft` (text), `card`/`cardAlt` (panels), and `glow(...)`/`drop(...)` shadow helpers over a candy color palette. Flip `NeonTheme.dark = true` (persisted via `StorageKeys.themeDark`) for a neon-dark palette instead — the same token getters resolve to different colors, no call site needs to change. `NeonTheme.colorBlindSafe` (persisted via `StorageKeys.colorBlindSafe`) is a separate, orthogonal flag for an accessible palette variant.

### Public API compatibility gate
`tool/api_compatibility.dart check` (run in CI before analyze/test) diffs `lib/roy_casual_kit.dart`'s exports against the committed `tool/api_snapshot.json`. Removing or renaming a public export fails CI; regenerate the snapshot with `dart run tool/api_compatibility.dart snapshot` only when the break is intentional.

### Testing gotcha: `NeonBg`'s ticker never settles
`NeonBg` (used by every `example/` screen) runs a permanent, never-stopping `Ticker` for its background animation. That means `pumpAndSettle()` will never return in any test that renders a screen wrapped in `NeonBg` — it just times out. Use a bounded `await tester.pump(const Duration(seconds: N))` instead (see `example/integration_test/app_boot_test.dart` and `example/test/settings_screen_test.dart` for the pattern already in use). A plain widget test can also wrap the tree in `TickerMode(enabled: false)` to suppress the ticker if it needs to avoid the animation entirely. The same applies to `RoyGame`/`GameWidget` (Flame's game loop is also a permanent `Ticker`) — see `test/presentation/game/roy_game_test.dart`.
