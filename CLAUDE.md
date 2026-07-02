# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Neon Jewels** — a match-3 mobile game (Flutter + GetX + Flame). Package: `com.galaxyjoy.neon_jewels`. 200 campaign levels across 10 worlds, 12+ side modes, full meta-progression system.

## Commands

```bash
# Run the everyday suite (unit + widget). Excludes `slow`-tagged integration
# tests, which drive the real app on a device (~5-8 min/case). See dart_test.yaml.
flutter test --exclude-tags slow

# Run a single test file
flutter test test/levels_test.dart

# Run a specific test by name
flutter test test/w20_content_test.dart --plain-name "kLevelCount"

# Run the full slow integration suite on a device (nightly / device-farm)
flutter test integration_test/app_test.dart -d <device-id>

# Static analysis (must be 0 issues before committing)
flutter analyze

# Run on connected device
flutter run -d <device-id>

# Build debug APK
flutter build apk --debug

# Validate difficulty curve for all 200 levels (lower-bound bot, no specials/boosters)
dart run tool/playtest.dart [runsPerLevel]

# Regenerate launcher icons (after updating asset/icon/ic_launcher.png)
dart run icons_launcher:create

# Regenerate native splash (after changing flutter_native_splash config in pubspec.yaml)
dart run flutter_native_splash:create
```

## Architecture

The codebase is split into 4 distinct layers with strict separation:

### 1. Pure Dart Logic (`lib/logic/`)
No Flutter, no Flame, no GetX. Fully unit-testable in isolation.
- **`match_detector.dart`** — detects all matches on a color grid; returns match groups with gem types (normal/striped/rainbow/bomb/diagonal/lightBall).
- **`settle.dart`** — gravity + refill engine for non-rectangular boards. `settleBoard` for standard gravity, `settleBoardFlow` for Gravity Streams (`FlowDir` per cell). `CellKind` enum: `play / wall / noDrop`.
- **`board_mechanics.dart`** — conveyor, portal, dispenser mechanics (pure functions).
- **`gem_data.dart`** — `GemColor` enum, `GemType` enum.
- **`rhythm_clock.dart`** — accumulates `dt` in game loop for rhythm beat detection (no `DateTime.now`).

### 2. Data / Config (`lib/data/`)
Pure Dart constants and data classes.
- **`levels.dart`** — `kLevels` (200-element list, generated via `List.generate`), `kWorlds` (10 world configs), all weave sets (`kBombLevels`, `kOrderLevels`, `kFlowLevels`, `kLayoutLevels`, etc.). Difficulty formulas: `_scorePerMove`, `_tierMul`, `_collectCapMul`. Layout maps use character strings: `.` = play, `#` = wall, `o` = noDrop, `v/^/</>` = flow direction.
- **`cosmetics.dart`** — `ActiveCosmetics` static holder (read each frame by Flame without `Get.find`).

### 3. Flame Engine (`lib/game/`)
- **`neon_jewel_game.dart`** — main `FlameGame`. Owns the gem grid (`List<List<GemComponent?>>`) and orchestrates swap → match → explode → settle → cascade. Reads mode flags from `GameController` but does NOT write them. Calls `controller.useMove()`, `controller.addScore()`, `controller.checkEnd()` after each turn.
- **`gem_component.dart`** — renders each gem (shape, glow, special indicators). Reads `ActiveCosmetics.gemSkin` for per-skin shape/color/glow.
- **`effects.dart`** — layer renderers: `TideLayer`, `SodaLayer`, `BlockedLayer`, `FlowLayer`, `ConveyorLayer`, `PortalLayer`, `DispenserLayer`, `BombLayer`.

### 4. GetX Presentation (`lib/presentation/`)

#### GameController — split into 8 `part` files
`game_controller.dart` is the root class; the 7 part files are **extensions on it** (`part of 'game_controller.dart'`). All share private fields and `_store`.
- `game_controller_modes.dart` — `startLevel`, `startEndless`, `startZen`, `startGhostMode`, `_enterMode` (mutually exclusive mode flags), ghost replay logic.
- `game_controller_scoring.dart` — `checkEnd`, `addScore`, `registerClear`.
- `game_controller_economy.dart` — `addCoins`, `spendCoins`, `_effectiveDay` (anti-cheat), `discountSideModeReward`.
- `game_controller_progress.dart` — `_saveProgress`, `resetProgress` (clears all keys + in-memory state of all permanent controllers).
- `game_controller_booster.dart`, `game_controller_cosmetics.dart`, `game_controller_lives.dart`.

**Key mode pattern**: `isSideMode` getter returns true for all non-campaign modes (Endless, Boss, Gravity, Rhythm, ColorRush, Soda, Survival, Labyrinth, Daily, Puzzle, Zen, Versus). Side modes MUST NOT touch win-streak/level-unlock/lives.

#### GameScreen / GameScreenController
`GameScreen` is a `StatelessWidget` driven entirely by `GameScreenController` (GetX). UI state is `GameUi` enum: `playing | quit | win | lose`. Win/lose dialogs are **in-tree overlays** (`NeonDialog.overlay`), NOT `Get.dialog` or `showDialog` (those are no-ops under full-screen Flame).

#### Permanent Controllers
All registered in `HomeScreen.build` via `Get.put(..., permanent: true)`. Includes: `GameController`, `AchievementController`, `LuckyWheelController`, `BattlePassController`, `SeasonLeagueController`, `CollectionController`, `PiggyController`, `SideModeRecordController`, `PuzzleController`, `ProgressionTreeController` (W20.3), `ChallengeCardController` (W20.3), `ClanController` (W23, offline), `StoryController`. Every non-`GameController` controller takes the `GameController` in its constructor. When adding a new permanent controller with persisted state, wire its `resetState()` into `resetProgress()` (see Reward Anti-Exploit below).

## Key Conventions

### Storage
All SharedPreferences keys live in `StorageKeys` class (`lib/core/storage_service.dart`). Never use string literals directly. `StorageService.to` is the singleton getter.

### Anti-cheat / Time
`_effectiveDay` (in `GameControllerEconomy`) returns the **maximum epoch-day ever seen**, preventing reward exploitation by setting the clock back. Daily/weekly features must read `todayEpochDay` (not `DateTime.now().epochDay` directly).

### Dialog pattern
Full-screen Flame app: `Get.dialog` and `showDialog` are no-ops. Always use `NeonDialog.overlay(panel: ...)` rendered as a widget in the Flutter tree above the `GameWidget`.

### i18n
Translation keys live in `AppTranslations` (`lib/core/app_translations.dart`). New keys go into `_extraEn` / `_extraVi` maps. For 20 other languages, add a new `_wXXByLang` const map and merge it with `...?_wXXByLang[e.key]` in the `keys` getter. The test `app_translations_test.dart` enforces ≥79% of values differ from English per language.

### Debug Logging
Use `dlog('message')` from `lib/core/debug_log.dart`. No-ops in release builds (tree-shaken). All debug prints are prefixed `roy93~` for easy logcat filtering.

### Playtest Validation
After changing level formulas or adding new levels, run `dart run tool/playtest.dart`. It simulates a greedy bot (no specials, no boosters = lower bound). Zero levels with pass-rate <25% is the requirement. Super-Hard levels are exempt from the guard.

### Reward Anti-Exploit
`resetProgress()` must clear **both** disk keys AND in-memory state of all permanent controllers (`resetState()` on each). Failing to do one causes re-claim exploits on app restart.
