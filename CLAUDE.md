# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Pop Star Blast** — a tap-to-pop puzzle game (Flutter + GetX + Flame). Package: `com.galaxyjoy.pop_star_blast` (Android), `com.galaxyjoy.popStarBlast` (iOS). Font: Baloo2. 200 campaign levels of increasing difficulty; a single campaign mode plus a coin shop and boosters (bomb / shuffle / undo).

> History: forked and fully rewritten from an older match-3 game. None of the old match-3 / side-mode / meta-progression code remains — do not reintroduce it.

## Commands

```bash
# Everyday suite (unit + widget). Excludes `slow`-tagged integration tests,
# which drive the real app on a device (~5-8 min/case). See dart_test.yaml.
flutter test --exclude-tags slow

# Run a single test file
flutter test test/data/levels_test.dart

# Run a specific test by name
flutter test test/data/levels_test.dart --plain-name "kLevelCount"

# Full slow integration suite on a device (nightly / device-farm)
flutter test integration_test/lifecycle_test.dart -d <device-id>

# Static analysis (must be 0 issues before committing)
flutter analyze

# Run on connected device
flutter run -d <device-id>

# Build debug APK
flutter build apk --debug
```

## Architecture

The codebase has 4 layers with strict separation:

### 1. Pure Dart Logic (`lib/logic/`)
No Flutter, no Flame, no GetX. Fully unit-testable in isolation. The grid is `List<List<int?>>` (color index, or `null` for an empty cell).
- **`pop_detector.dart`** — `findConnectedGroup(grid, row, col)`: flood-fill (4-directional) of same-color adjacent cells; returns the group (size ≥1, caller enforces the ≥2 threshold to pop). `hasAnyMovableGroup(grid)`: is there any poppable group ≥2 left (used to detect a stuck board).
- **`pop_collapse.dart`** — `applyGravityAndCollapse(grid)`: gravity within each column (cells fall to the bottom), then fully-empty columns collapse to the left. **No refill** — the board only drains, matching classic PopStar rules. Mutates in place and returns the grid.

### 2. Data / Config (`lib/data/`)
- **`levels.dart`** — `PopLevel` (id, rows, cols, colorCount, targetScore), `kLevels` (200-element list via `List.generate`), `kLevelCount = 200`. `scoreForGroup(n) = 5*n*(n-1)`, `clearBoardBonus = 1000`. Difficulty grows every 20 levels (rows 8..11, cols 6..12, colors 4..7). Because the board is finite with no refill, achievable score scales with cell count, so `targetScore` anchors to `cells * 6 * ramp` (ramp = `1 + world*0.03`), not the level index.

### 3. Flame Engine (`lib/game/`)
- **`pop_star_game.dart`** — main `FlameGame`. Owns `colorGrid` (source of truth) and `_blocks` (`BlockComponent` per cell). Flow: tap → `_tryPop` finds the group → score → `_clearAndCollapse` animates a pop burst (scale + particles), then `_collapseAnimated` tweens columns/blocks into place. `_animating` locks input during animation. `backgroundColor()` is transparent so the candy background shows through. Boosters operate directly on the grid: `triggerBomb(r,c)` (3x3), `shuffleBoard()`, `undo()` (single-step snapshot). `_checkEnd()` calls `controller.checkEnd(cleared)` when the board is empty or stuck. Tap comes from a `GestureDetector` in `game_screen.dart` via `handleTap` (not Flame's TapDetector).
- **`block_component.dart`** — renders one gem (neon candy look) from its `colorIndex`.

### 4. GetX Presentation (`lib/presentation/`)

#### Controllers (`lib/presentation/controllers/`)
- **`game_controller.dart`** — single file, **no `part` splitting**. Holds reactive game state (`score`, `coins`, `starsEarned`, `ended`, `cleared`, `currentLevelRx`, `unlockedLevel`) and booster counts (`bombCount`, `shuffleCount`, `undoCount`) as `RxInt`/`Rx`. `startLevel`, `addScore`, `checkEnd` (computes stars vs `targetScore`, unlocks next level, saves best score/star, grants coins). Shop buys (`buyBomb`/`buyShuffle`/`buyUndo`) and uses (`useBomb`/`useShuffle`/`useUndo`) that delegate to `activeGame`. `resetProgress()` clears all disk keys **and** in-memory state.
- **`game_screen_controller.dart`** — drives `GameScreen`. `GameUi` enum: `playing | quit | win | lose`. `BoosterMode` enum: `none | bomb`. Level end is **asynchronous** (it fires after the pop/fall animation), so it listens reactively via `ever(gameCtrl.ended, ...)` rather than checking right after a tap. Manages wakelock, the Flame game instance, and `again`/`next`/`quit`.

#### Screens (`lib/presentation/screens/`)
`home_screen`, `level_select_screen` (200-level grid), `game_screen`, `shop_screen`, `guide_screen`, `settings_screen`. `GameScreen` is a widget driven entirely by `GameScreenController`.

#### Widgets (`lib/presentation/widgets/`)
`neon_button`, `neon_dialog`, `neon_app_bar`, `neon_bg`, `coin_chip`, `neon_icon`, `stroke_text` (outlined text), `confetti_overlay`.

#### Registration
Permanent singletons are registered in `main.dart` via `Get.put(..., permanent: true)`: `StorageService`, `LocaleService`, `GameController`, `AudioManager`. `GameScreenController` is a per-screen controller (`Get.put` in `GameScreen.build`, deleted on quit).

## Key Conventions

### Storage
All SharedPreferences keys live in `StorageKeys` (`lib/core/storage_service.dart`) — never use string literals. Per-level keys are helpers: `highScore(id)`, `star(id)`. `StorageService.to` is the singleton getter.

### Reactive unlock / async end
`unlockedLevel` is an observable on `GameController` so `LevelSelect` refreshes the moment a level is won. Level end is emitted through `gameCtrl.ended` (an `Rx<bool>`) because it happens after the Flame animation completes — consumers must observe it, not poll after a tap.

### Target achievability
Because the board never refills, a level is only winnable if `targetScore` is reachable from the finite starting cells. Keep `targetScore` anchored to cell count (`cells * 6 * ramp`) — do not switch to level-index-linear scaling (it made most levels impossible; see `doc/feat.md`).

### Dialog pattern
Full-screen Flame app: `Get.dialog` and `showDialog` are no-ops (can't push a route over the `GameWidget`). Always render dialogs as in-tree overlays via `NeonDialog.overlay(panel: ...)` above the `GameWidget`.

### i18n
Translations live in `AppTranslations` (`lib/core/app_translations.dart`), 22 supported locales (`AppTranslations.supported`). New keys go into the English base map (fallback) and per-language override maps. The test `app_translations_test.dart` enforces every language has the full key set.

### Debug Logging
Use `dlog('message')` from `lib/core/debug_log.dart`. No-ops in release builds (tree-shaken). All debug prints are prefixed `roy93~` for easy logcat filtering.

### Theme
`NeonTheme` (`lib/core/neon_theme.dart`) was pivoted to a **bright-casual (Candy-Crush-style)** look: light candy-sky gradient background, tokens `ink`/`inkSoft` (text), `card`/`cardAlt` (panels), and `glow(...)` / `drop(...)` shadow helpers over a candy color palette.
