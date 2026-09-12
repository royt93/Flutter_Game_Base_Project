# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**roy_casual_kit** — a Flutter *package* (not an app): local storage, i18n,
audio, haptics, local reminders, theme tokens, and a candy-styled casual-game
widget kit, built on GetX. Package name: `roy_casual_kit`. Font: Baloo2.

The repo has two parts:
- Root `lib/` — the package itself. Only core services (`lib/core/`) and
  widgets (`lib/presentation/widgets/`) live here. No `main.dart`, no
  screens, no `android/`/`ios/` at the root.
- `example/` — a **separate** Flutter app with its own `pubspec.yaml`,
  `android/`, `ios/`, and `lib/main.dart` + 3 screens
  (`HomeScreen`/`SettingsScreen`/`WidgetShowcaseScreen`). It depends on the
  root package via `path: ../` in `example/pubspec.yaml`.

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
a new integration test ends up slow. CI (`.github/workflows/ci.yml`) runs
analyze + test at the root, then repeats both `working-directory: example`.

Root tests mirror `lib/`: `test/core`, `test/core/utils`, `test/widget`
(+ `test/widget/common`, `test/widget/goldens`). `example/test/` holds
widget tests for the demo screens; `example/integration_test/` has the
device boot test. Add `test/logic`/`test/data` at the root only if a
Flutter-free pure-Dart layer is ever added to the package (none exists today).

## Architecture

### 1. Core services (`lib/core/`, `lib/core/utils/`)
- **`storage_service.dart`** — `StorageService` (a `GetxService` wrapping `SharedPreferences`, singleton via `StorageService.to`) and `StorageKeys` (currently 12 constants: `localeCode`, `audioMuted`, `themeDark`, `hapticsEnabled`, `hapticSoftMode`, `maxEpochDaySeen`, `maxMsSeen`, `energyCount`, `energyLastMs`, `energyInfiniteUntilMs`, `offlineLastClaimedMs`, `reviewLastAskedMs`). Never use string literals for prefs keys — add a new named constant instead. Falls back to an in-memory map if `SharedPreferences.getInstance()` throws at boot, so a broken-storage device doesn't crash white-screen. Also has a write-behind buffer (`setIntBuffered`/`setStringBuffered` + `flush()`) for hot-path counters where a missed write on kill is acceptable — real transactions (purchases, resets) must use the unbuffered `setInt`/`setString` so they're never lost.
- **`app_translations.dart`** — `AppTranslations`, 2 seed locales (`en`/`vi`), 10 base keys (`app_name`, `settings`, `language`, `sound`, `dark_mode`, `ok`, `cancel`, `widget_showcase`, `back_button_label`, `game_demo`). Copy this file's one-`Map`-per-locale pattern when a consumer needs more languages/keys.
- **`locale_service.dart`** — `LocaleService`, persists the chosen locale via `StorageKeys.localeCode` and falls back to device locale, then `AppTranslations.fallback`. Depends on `AppTranslations.codeOf(Locale)` to round-trip a locale to/from its stored string.
- **`audio_manager.dart`** — `AudioManager`, one background track + mute, persists mute via `StorageKeys.audioMuted`. `AudioManager.maybe` is the null-safe accessor for call sites that may run before/without audio registered (e.g. widget tests).
- **`haptics.dart`** — `fireHaptic(HapticLevel)`, gated on `StorageKeys.hapticsEnabled`/`hapticSoftMode`. Every `HapticFeedback.*` call in a consumer app should go through here, not call the platform API directly.
- **`neon_theme.dart`** — `NeonTheme` design tokens: `dark` flag (bright-casual light theme by default, flip for a neon-dark palette), spacing constants, candy color palette, `glow(...)`/`drop(...)` shadow helpers.
- **`reminder_service.dart`** — `ReminderService`, one scheduled local notification. A consumer app that needs several reminder kinds should extend this, not add branches here.
- **`share_helper.dart`** — `shareText`/`shareBoardImage`/`shareScoreCard`/`shareJourneyCard`, one `share_plus` pipeline for text or `RepaintBoundary`-captured PNGs.
- **`app_info.dart`** — `kAppName`, `kCopyright`, `kAppVersion`/`kAppBuildNumber` (auto-loaded from the consuming app's `pubspec.yaml` via `package_info_plus`), `kPackageName` (same, read from the platform package id).
- **`runtime_flags.dart`** — `isE2eTest` (`--dart-define=E2E_TEST=true`), used to skip audio init during automated device tests so `audioplayers`' frame callback doesn't outlive `tearDown`.
- **`debug_log.dart`** — `dlog('message')`, no-op in release builds (tree-shaken), all output prefixed `roy93~` for logcat filtering.
- **`utils/clamped_clock.dart`** — `nowMsClamped()`/`todayEpochDayClamped()`, a monotonic (never-goes-backward) clock built on `StorageKeys.maxMsSeen`/`maxEpochDaySeen`, for any time-gated reward system that shouldn't be exploitable by turning the device clock back.
- **`utils/format.dart`** — `fmtDur` (mm:ss), `durationToLocalMidnight`, `fmtNum` (locale-aware thousands separator via `intl`).
- **`utils/label_fit.dart`** — `fitFontSizeForLongestWord`, shrinks a label's font size until every individual word (not the whole string) fits a max width — guards against mid-word line breaks in long-word languages (German, etc.).
- **`utils/safe_json.dart`** — `asIntOr`/`asStringOr`/`asDoubleOr`, tolerant type-coercing readers for a decoded JSON map (e.g. a `VersionedJsonStore` payload) where a field might be the wrong type or missing.
- **`utils/throttle.dart`** — `throttled(VoidCallback, {Duration window})`, wraps a callback so rapid repeat calls (double-tap, spam) within `window` are dropped after the first.
- **`utils/weighted_random_pick.dart`** — `weightedRandomPick<T>(...)`, picks one item from a weighted list (loot tables, reward rarities).
- **`offline_progression_service.dart`** — `OfflineProgressionService`, idle/offline earnings (`min(elapsed, maxOfflineCap) * rate`) since the last claim, built on `nowMsClamped()` so winding the device clock back can't re-farm the payout. No "watch an ad to double" flow — that's layered on top of `claim()` by the consumer app.
- **`versioned_json_store.dart`** — `VersionedJsonStore<T>`, a thin versioned-JSON-object store on top of `StorageService`'s plain key/value strings, for save data with real shape (player profile, level progress) that must survive a schema change between game versions — caller supplies `toJson`/`fromJson`/a `migrate` step, and (optionally) a `CloudSaveProvider` to `syncWith`.
- **`performance_tier_service.dart`** — `PerformanceTierService`, a pure FPS tracker (no `SchedulerBinding` dependency, unit-testable with synthetic frame durations) with hysteresis (separate downgrade/upgrade FPS thresholds) that decorative shader/ticker layers (`AuroraBgLayer`/`NeonAuraLayer`, via `ShaderTickerLayerState`) check to decide whether to keep animating.
- **`daily_login_service.dart`** — `DailyLoginService`, a repeating 7-day login-streak cycle (`claimToday()`), day 1..7 then wraps back to day 1.
- **`energy_service.dart`** — `EnergyService`, a refill-over-time energy/lives system (Candy Crush-style hearts) — current energy is computed lazily from elapsed time via `nowMsClamped()`, never `DateTime.now()` directly, for the same anti-clock-rewind reason as `ClampedClock`.
- **`achievement_service.dart`** — `AchievementService` (a `GetxService`), local achievement/badge progress tracking — no Game Center/Play Games dependency.
- **`save_integrity.dart`** — an HMAC checksum layer over `StorageService.exportAll()`/`importAll()`: sign a save on export, verify on import, so a consuming game can detect a hand-edited save (e.g. an externally bumped coin count).
- **`in_app_review_helper.dart`** — `InAppReviewHelper`, decision logic for "should we ask for a store review right now" (the classic casual-game pattern: prompt right after a happy moment, not too often) — platform-neutral, no concrete review-prompt SDK baked in.
- **Seams (platform-neutral, no concrete SDK dependency; a consumer app implements and registers its own adapter via `Get.put<X>(myAdapter, permanent: true)`)** — `crash_reporter.dart` (`CrashReporter`, since `dlog()` is debug-only/tree-shaken from release builds), `analytics_provider.dart` (`AnalyticsProvider` + a `NoopAnalyticsProvider` default), `cloud_save_provider.dart` (`CloudSaveProvider`, passed to `VersionedJsonStore.syncWith`), `remote_config_service.dart` (`RemoteConfigService`, feature-flag/remote-config seam), `purchase_seam.dart` (`PurchaseSeam` — minimal `buy`/`restorePurchases`/`isOwned` IAP seam, no `Noop*` default on purpose since silently no-op'ing a purchase would hide a real integration bug).

### 2. Widgets (`lib/presentation/widgets/`)
- **Neon kit** (loose files, not in `common/`) — `NeonButton`, `NeonDialog`, `NeonAppBar`, `NeonBg`, `NeonAuraLayer`, `AuroraBgLayer`, `NeonIcon`, `StrokeText`, `PressableScale`.
- **`common/`** — 40 generic, game-agnostic widgets plus a barrel
  (`common_widgets.dart`) exporting all of them in one import:
  - Buttons & interactive (5): `CommonButton` (4 variants: primary/secondary/danger/icon), `ToggleSwitch`, `SegmentedTabBar`, `IconBadgeButton`, `SoundToggleFab`.
  - Feedback & overlay (10): `LoadingOverlay`, `ToastBanner`, `TooltipBubble`, `BottomSheetPanel`, `ConfirmDialog`, `ConfettiOverlay`, `FloatingComboText`, `NetworkStatusBanner`, `ShimmerPlaceholder`, `SpotlightOverlay`.
  - Progress & reward (12): `ProgressBarStars`, `CircularProgressRing`, `StarRating`, `CurrencyCounter`, `RewardPopup`, `BadgeDot`, `StreakCounter`, `CountdownChip`, `PaginatedDotsIndicator`, `CoinFlyOverlay`, `DailyLoginCalendarWidget`, `EnergyBar`.
  - Layout & cards (9): `PanelCard`, `ListTileRow`, `SectionHeader`, `EmptyStatePlaceholder`, `AvatarFrame`, `RibbonBadge`, `ShopItemCard`, `VictoryCardTemplate`, `LeaderboardList`.
  - Game-specific (1): `LevelSelectGrid`.
  - Game-feel / juice (3): `SquashStretch`, `ScreenShake`, `ComboHeatBackground`.
  - `CommonButton` is a superset of `NeonButton` (more variants) — `NeonButton` stays as-is, this doesn't replace it.
  - `example/lib/screens/widget_showcase_screen.dart` is the living reference for how each one is meant to be used — check it before guessing a constructor signature.

### 3. `example/` app
A standalone Flutter app depending on the root package via `path: ../`.
`example/lib/main.dart` registers permanent singletons via
`Get.put(..., permanent: true)` (`StorageService`, `LocaleService`,
`ReminderService`, and — unless `withAudio: false`, e.g. under
`isE2eTest` — `AudioManager`) and boots `GetMaterialApp`. Screens:
`HomeScreen` (title + button to Settings), `SettingsScreen` (locale
dropdown + audio mute toggle), `WidgetShowcaseScreen` (demos every
`common/` widget, section by section). Any new demo screen or
app-specific behavior belongs here, not in the package `lib/`.

## Key Conventions

### Storage
See `storage_service.dart` above — `StorageKeys` holds every persisted key, `StorageService.to` is the singleton getter. Anything storing an id from a const table (skins, unlocks, etc.) must re-validate on load rather than trust a stale id.

### Dialog pattern
`NeonDialog.show(...)`/`NeonDialog.overlay(panel: ...)` render dialogs as in-tree overlays rather than pushing a route. This exists because a full-screen Flame `GameWidget` (if a consumer app builds one — `flame` is a dependency of this package for exactly that use case) makes `Get.dialog`/`showDialog` no-ops: nothing can push a route over it. Prefer the overlay pattern for any dialog from the start so it isn't a rewrite later.

### i18n
Translations live in `AppTranslations` (`lib/core/app_translations.dart`), 2 supported locales (`AppTranslations.supported`: `en`, `vi`). New keys go into both locale maps — `test/core/app_translations_test.dart` enforces key parity between locales, so a key added to only one map fails the suite immediately.

### Debug Logging
Use `dlog('message')` from `lib/core/debug_log.dart`. No-ops in release builds. All debug prints are prefixed `roy93~` for easy logcat filtering.

### Theme
`NeonTheme` (`lib/core/neon_theme.dart`) is a bright-casual (Candy-Crush-style) look by default: light candy-sky gradient background, tokens `ink`/`inkSoft` (text), `card`/`cardAlt` (panels), and `glow(...)`/`drop(...)` shadow helpers over a candy color palette. Flip `NeonTheme.dark = true` (persisted via `StorageKeys.themeDark`) for a neon-dark palette instead — the same token getters resolve to different colors, no call site needs to change.

### Testing gotcha: `NeonBg`'s ticker never settles
`NeonBg` (used by every `example/` screen) runs a permanent, never-stopping `Ticker` for its background animation. That means `pumpAndSettle()` will never return in any test that renders a screen wrapped in `NeonBg` — it just times out. Use a bounded `await tester.pump(const Duration(seconds: N))` instead (see `example/integration_test/app_boot_test.dart` and `example/test/settings_screen_test.dart` for the pattern already in use). A plain widget test can also wrap the tree in `TickerMode(enabled: false)` to suppress the ticker if it needs to avoid the animation entirely.
