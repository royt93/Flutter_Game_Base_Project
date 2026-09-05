# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Roy Project Base Game** — a lean Flutter + GetX + Flame starting point, not a shipped game. Package: `com.galaxyjoy.roybasegame` (Android), `com.galaxyjoy.royBaseGame` (iOS). Font: Baloo2.

This repo was stripped down from a full match-3 game (Pop Star Blast) to just the reusable core: local storage, i18n, audio, haptics, local reminders, theme tokens, and a small neon-styled widget kit. `lib/logic/`, `lib/data/`, and `lib/game/` — the pure-Dart rules layer, static content layer, and Flame engine layer — don't exist yet; they're empty on purpose (git doesn't track empty directories) for whatever game gets built on this base. Don't assume a `GameController`, level data, or a `GameMode` system exists — none of that survived the strip. If you need the original game's approach as a worked example, it's in git history before this rename.

## Commands

```bash
# Everyday suite (unit + widget).
flutter test --exclude-tags slow

# Run a single test file
flutter test test/core/storage_service_test.dart

# Run a specific test by name
flutter test test/core/storage_service_test.dart --plain-name "some test name"

# Device smoke test (boots the app to HomeScreen)
flutter test integration_test/app_boot_test.dart -d <device-id>

# Static analysis (must be 0 issues before committing)
flutter analyze

# Run on connected device
flutter run -d <device-id>

# Build debug APK
flutter build apk --debug
```

`dart_test.yaml` declares a `slow` tag for future heavy device-driven integration tests (nightly / device-farm style) — nothing currently carries that tag, so `--exclude-tags slow` is a no-op today, but keep tagging that way if a new integration test ends up slow.

Tests mirror the source layout: `test/core`, `test/core/utils`, `test/widget` (+ `test/widget/goldens`). Add `test/logic`/`test/data` when those source directories exist — that layer is meant to be Flutter-free so it needs no widget harness.

## Architecture

### 1. Core services (`lib/core/`, `lib/core/utils/`)
- **`storage_service.dart`** — `StorageService` (a `GetxService` wrapping `SharedPreferences`, singleton via `StorageService.to`) and `StorageKeys` (currently 7 constants: `localeCode`, `audioMuted`, `themeDark`, `hapticsEnabled`, `hapticSoftMode`, `maxEpochDaySeen`, `maxMsSeen`). Never use string literals for prefs keys — add a new named constant instead. Falls back to an in-memory map if `SharedPreferences.getInstance()` throws at boot, so a broken-storage device doesn't crash white-screen. Also has a write-behind buffer (`setIntBuffered`/`setStringBuffered` + `flush()`) for hot-path counters where a missed write on kill is acceptable — real transactions (purchases, resets) must use the unbuffered `setInt`/`setString` so they're never lost.
- **`app_translations.dart`** — `AppTranslations`, 2 seed locales (`en`/`vi`), 6 base keys (`app_name`, `settings`, `language`, `sound`, `ok`, `cancel`). Copy this file's one-`Map`-per-locale pattern when a game needs more languages/keys.
- **`locale_service.dart`** — `LocaleService`, persists the chosen locale via `StorageKeys.localeCode` and falls back to device locale, then `AppTranslations.fallback`. Depends on `AppTranslations.codeOf(Locale)` to round-trip a locale to/from its stored string.
- **`audio_manager.dart`** — `AudioManager`, one background track (`asset/audio/bkg.ogg`) + mute, persists mute via `StorageKeys.audioMuted`. `AudioManager.maybe` is the null-safe accessor for call sites that may run before/without audio registered (e.g. widget tests, integration tests with `withAudio: false`).
- **`haptics.dart`** — `fireHaptic(HapticLevel)`, gated on `StorageKeys.hapticsEnabled`/`hapticSoftMode`. Every `HapticFeedback.*` call in the app should go through here, not call the platform API directly.
- **`neon_theme.dart`** — `NeonTheme` design tokens: `dark` flag (bright-casual light theme by default, flip for the original neon-dark palette), spacing constants, candy color palette, `glow(...)`/`drop(...)` shadow helpers.
- **`reminder_service.dart`** — `ReminderService`, one scheduled local notification. Games that need several reminder kinds should extend this, not add branches here.
- **`share_helper.dart`** — `shareText`/`shareBoardImage`/`shareScoreCard`/`shareJourneyCard`, one `share_plus` pipeline for text or `RepaintBoundary`-captured PNGs. `shareScoreCard`/`shareJourneyCard` are dead code today (no `ScoreCard`/`JourneyCard` widget survived the strip) but the filenames they'd share are still current (`roy_base_game*.png`).
- **`app_info.dart`** — `kAppName`, `kCopyright`, `kAppVersion`/`kAppBuildNumber` (auto-loaded from `pubspec.yaml` via `package_info_plus` at boot, see `loadAppVersion()` in `main.dart`), `kPackageName` (same, read from the platform package id).
- **`runtime_flags.dart`** — `isE2eTest` (`--dart-define=E2E_TEST=true`), used to skip audio init during automated device tests so `audioplayers`' frame callback doesn't outlive `tearDown`.
- **`debug_log.dart`** — `dlog('message')`, no-op in release builds (tree-shaken), all output prefixed `roy93~` for logcat filtering.
- **`utils/clamped_clock.dart`** — `nowMsClamped()`/`todayEpochDayClamped()`, a monotonic (never-goes-backward) clock built on `StorageKeys.maxMsSeen`/`maxEpochDaySeen`, for any future time-gated reward system that shouldn't be exploitable by turning the device clock back.
- **`utils/format.dart`** — `fmtDur` (mm:ss), `durationToLocalMidnight`, `fmtNum` (locale-aware thousands separator via `intl`).
- **`utils/label_fit.dart`** — `fitFontSizeForLongestWord`, shrinks a label's font size until every individual word (not the whole string) fits a max width — guards against mid-word line breaks in long-word languages (German, etc.).

### 2. GetX Presentation (`lib/presentation/`)
- **Screens (`lib/presentation/screens/`)** — `HomeScreen` (title + a button to Settings) and `SettingsScreen` (locale dropdown + audio mute toggle). Both are placeholders exercising the kept services end to end; replace them with your game's real screens rather than growing these.
- **Widgets (`lib/presentation/widgets/`)** — `neon_button`, `neon_dialog`, `neon_app_bar`, `neon_bg`, `neon_icon`, `stroke_text`, `pressable_scale`, plus two shader/particle background layers: `aurora_bg_layer`, `neon_aura_layer`. This is the full widget kit — `ambient_particles`, `ambient_weather_layer`, `coin_chip`, `confetti_overlay`, and `pulse_glow` were deleted as dead weight during the strip (recoverable from git history at commit `9262a03^` if a future project wants them). `neon_bg.dart` itself survives but lost its `weather:` parameter/ambient-weather integration.
- **Registration** — `main.dart` registers permanent singletons via `Get.put(..., permanent: true)`: `StorageService`, `LocaleService`, `ReminderService`, and (unless `withAudio: false`, e.g. under `isE2eTest`) `AudioManager`. There is no per-run controller layer yet — add one (`Get.put` in a screen's `build`/`onInit`, deleted on exit) when a real game controller shows up.

## Key Conventions

### Storage
See `storage_service.dart` above — `StorageKeys` holds every persisted key, `StorageService.to` is the singleton getter. Anything storing an id from a const table (skins, unlocks, etc., once such tables exist again) must re-validate on load rather than trust a stale id.

### Dialog pattern
`NeonDialog.show(...)`/`NeonDialog.overlay(panel: ...)` render dialogs as in-tree overlays rather than pushing a route. This exists because a full-screen Flame `GameWidget` (once one exists again — `flame` is still a dependency, kept for the game layer this base is meant to grow) makes `Get.dialog`/`showDialog` no-ops: nothing can push a route over it. Prefer the overlay pattern for any dialog from the start so it isn't a rewrite later.

### i18n
Translations live in `AppTranslations` (`lib/core/app_translations.dart`), 2 supported locales (`AppTranslations.supported`: `en`, `vi`). New keys go into both locale maps — there's no test enforcing key parity yet at this size, but keep every locale's key set identical as more languages are added.

### Debug Logging
Use `dlog('message')` from `lib/core/debug_log.dart`. No-ops in release builds. All debug prints are prefixed `roy93~` for easy logcat filtering.

### Theme
`NeonTheme` (`lib/core/neon_theme.dart`) is a bright-casual (Candy-Crush-style) look by default: light candy-sky gradient background, tokens `ink`/`inkSoft` (text), `card`/`cardAlt` (panels), and `glow(...)`/`drop(...)` shadow helpers over a candy color palette. Flip `NeonTheme.dark = true` (persisted via `StorageKeys.themeDark`) for the original neon-dark palette instead — the same token getters resolve to different colors, no call site needs to change.
