# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Pop Star Blast** — a tap-to-pop puzzle game (Flutter + GetX + Flame). Package: `com.galaxyjoy.pop_star_blast` (Android), `com.galaxyjoy.popStarBlast` (iOS). Font: Baloo2.

Core loop: a 220-level campaign (11 worlds × 20 levels, `lib/data/worlds.dart`) with a coin shop and boosters (bomb / shuffle / undo / rainbow / swap / freeze). Around that core, `GameController` also drives **9 side game modes** (time attack, zen, endless, daily challenge, puzzle lab, boss rush, mirror mode, gauntlet, weekly featured — see `GameMode` enum below) plus a wide layer of meta-progression: prestige/New Game+, achievements, weekly goals, login streaks, a season pass, cosmetics (mascot skins, board frames, burst styles, combo-text styles), and social-lite features (challenge codes, ghost replay, offline leaderboards). None of this meta layer has a real backend — it's all local `SharedPreferences` state; see "Meta-progression & side modes" below before assuming a system is more connected than it is.

> History: forked and fully rewritten from an older match-3 game. None of the *old match-3* code remains (no `match_detector`/`settle`/world-map-as-navigation from that era) — do not reintroduce it. This does **not** mean the game is a single-mode campaign; see below.

## Commands

```bash
# Everyday suite (unit + widget). Excludes `slow`-tagged integration tests,
# which drive the real app on a device (~5-8 min/case). See dart_test.yaml.
flutter test --exclude-tags slow

# Run a single test file
flutter test test/data/levels_test.dart

# Run a specific test by name
flutter test test/data/levels_test.dart --plain-name "kLevelCount"

# Full slow integration suite on a device (nightly / device-farm).
# --dart-define=E2E_TEST=true is required for any test that calls
# restartApp() (e.g. backup_restore_test.dart) — without it AudioManager
# re-inits on restart and leaks a frame callback past tearDown, which the
# scheduler reports as a false test failure.
flutter test integration_test/lifecycle_test.dart -d <device-id> --dart-define=E2E_TEST=true

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
No Flutter, no Flame, no GetX. Fully unit-testable in isolation. The grid is `List<List<int?>>` (color index ≥0, or a negative sentinel for a special tile, or `null` for an empty cell).
- **`pop_detector.dart`** — `findConnectedGroup(grid, row, col)`: flood-fill (4-directional) of same-color adjacent cells (respects `lockGrid` for chain tiles; wildcard tiles match any color but don't bridge two different-color groups). `findLargestGroup()` scans for hint purposes. `hasAnyMovableGroup(grid)`: stuck-board detection.
- **`pop_collapse.dart`** — `applyGravityAndCollapse(grid)`: gravity within each column, then empty columns collapse left. Generic across 4 gravity directions (`GravityDirection`, a per-level property) via coordinate transform. **No refill** in campaign — the board only drains (Zen mode is the one exception, see below). Keeps a parallel `lockGrid` in sync for chain tiles.
- **`obstacle.dart`** — obstacles encode as negative durability (`-d`); adjacent pops chip 1 durability, breaking at 0.
- **`boss_tile.dart`** — boss tiles occupy a rectangular region sharing one ID (≤ -2000); HP lives in a separate `Map<int,int>` keyed by ID, not in the grid. Distinct from `PopLevel.isBoss` (that just scales target score).
- **`gift_tile.dart`** — gift tiles (`-1000`) auto-open when they reach the bottom row, yielding a random `GiftReward` (coins/bomb/shuffle/undo).
- **`wildcard_tile.dart`** — wildcard tiles (`-500`) match any color in flood-fill; tapped directly, they inherit a neighbor's color.
- **`power_tile.dart`** — pops of size 5-6/7-8/≥9 spawn a line/bomb/rainbow power tile (`powerTileKindForGroupSize`).
- **`chain_tile.dart`** — real-colored tiles locked for K adjacent pops, tracked via the parallel `lockGrid`.
- **`countdown_lock_tile.dart`** — counts down 1 per tap anywhere on the board, then converts to a plain obstacle.
- **`time_freeze_tile.dart`** — pure predicate tagging a cell with a Time Attack time-freeze bonus.
- **`daily_challenge.dart`** — `generateDailyChallengeGrid()`: seeded-by-epoch-day board, identical for every player that day; reused by Gauntlet.
- **`leaderboard.dart`** — offline leaderboard simulation: merges a static bot list with the player's score, sorts, ranks. No network.
- **`login_streak.dart`**, **`craft_points.dart`**, **`replay.dart`** (deterministic seed+taps replay, campaign-only), **`challenge_code.dart`** (peer score-only challenge), **`puzzle_code.dart`** (Puzzle Lab board encode/decode), **`backup_code.dart`** (AES-GCM encrypted save backup) — self-contained, see file docs.

### 2. Data / Config (`lib/data/`)
- **`levels.dart`** — `PopLevel`, `kLevels` (220 entries via `List.generate`), `kLevelCount = 220`. `scoreForGroup(n) = 5*n*(n-1)`. Difficulty ramps every 20 levels (rows 8..11, cols 6..12, colors 4..7). `targetScore` anchors to `cells * 6 * ramp` (ramp = `1 + world*0.03`) — see "Target achievability" below, this constraint still holds.
- **`worlds.dart`** — 11 worlds (20 levels each) with name/color/icon/weather.
- **`weekly_goal.dart`** — fixed 300-gem weekly target, cumulative across *all* modes, resets on week boundary.
- **`achievements.dart`** — 25 vanity-only achievements (`AchievementMetric` × 5 tiers) over lifetime metrics; coin reward, one-time unlock, no gameplay effect.
- **`board_frames.dart`**, **`burst_styles.dart`**, **`combo_text_styles.dart`**, **`mascot_skins.dart`** — cosmetic unlock tables (gated by coins, prestige tier, or achievement thresholds).
- **`combo_milestones.dart`** — fixed combo breakpoints (5/10/15/20) for VFX/haptics.
- **`perks.dart`** — permanent per-world-completion unlocks (extra undo, hint, coin bonus); pick up to 2 active.
- **`boss_rush.dart`** — generates Boss Rush stages on the fly from already-unlocked world geometry, 5%/stage scaling.
- **`mirror_board.dart`** — symmetric board generator for Mirror Mode.
- **`lucky_color.dart`**, **`weekly_featured.dart`**, **`gauntlet_modifiers.dart`** — deterministic per-day/per-week pickers (epoch-seeded, same for every player).
- **`*_leaderboard_bots.dart`** (daily challenge / gauntlet / weekly featured / generic) — static bot score tables feeding the offline leaderboard.

### 3. Flame Engine (`lib/game/`)
- **`pop_star_game.dart`** — main `FlameGame`. Owns `colorGrid` (source of truth) and `_blocks` (`BlockComponent` per cell). Flow: tap → `_tryPop` finds the group → score → `_clearAndCollapse` animates a pop burst (scale + particles), then `_collapseAnimated` tweens columns/blocks into place. `_animating` locks input during animation. `backgroundColor()` is transparent so the candy background shows through. Boosters operate directly on the grid: `triggerBomb(r,c)`, `shuffleBoard()`, `undo()` (single-step snapshot), plus rainbow/swap/freeze. `_checkEnd()` calls `controller.checkEnd(cleared)` when the board is empty or stuck. Tap comes from a `GestureDetector` in `game_screen.dart` via `handleTap` (not Flame's TapDetector). Same engine instance is reused for every `GameMode` — mode-specific rules (refill, timer, modifiers) are parameters/flags passed in at start, not separate engines.
- **`block_component.dart`** — renders one gem (candy look) from its `colorIndex`, plus overlays for special tiles (obstacle/gift/boss/wildcard/chain/countdown/power).

### 4. GetX Presentation (`lib/presentation/`)

#### Controllers (`lib/presentation/controllers/`)
- **`game_controller.dart`** — single file, **no `part` splitting** (~1700 lines — it's the biggest single source of truth in the app; read it in full before making cross-cutting changes). Holds reactive campaign state (`score`, `coins`, `starsEarned`, `ended`, `cleared`, `currentLevelRx`, `unlockedLevel`), booster counts/prices, and **all** meta-progression state (prestige, achievements, weekly goal, daily reward + daily spin, login streak, season pass, cosmetics, per-mode best scores). See "Meta-progression & side modes" below for the `GameMode` system it drives.
- **`game_screen_controller.dart`** — drives `GameScreen`. `GameUi` enum: `playing | quit | win | lose`. `BoosterMode` enum: `none | bomb`. Level end is **asynchronous** (fires after the pop/fall animation), so it listens reactively via `ever(gameCtrl.ended, ...)` rather than checking right after a tap. Manages wakelock, the Flame game instance, `again`/`next`/`quit`.
- **`boss_rush_controller.dart`** — orchestrates a single Boss Rush run (stage progression, lives, best streak) separately from `GameController` to avoid a circular dependency; `PopStarGame` calls `advanceStage()` on win, keeping the same engine instance across stages so combo/score chain.
- **`home_screen_controller.dart`** — builds the home screen's progress-carousel card list (`buildHomeCards`), refreshed on resume so it reflects state changed on other screens.

#### Screens (`lib/presentation/screens/`)
Core: `home_screen`, `level_select_screen` (220-level grid), `game_screen`, `shop_screen`, `guide_screen`, `settings_screen`. `GameScreen` is driven entirely by `GameScreenController`.
Modes/meta, added since the game grew past a single campaign mode: `boss_rush_screen`, `puzzle_lab_screen` (in-app level editor, saves up to 5 boards locally, share via `puzzle_code.dart`), `season_screen` (28-day free season pass), `star_road_screen`, `achievements_screen`, `trophy_room_screen` (prestige tier + unlocked achievements + owned mascot skins, read-only), `stats_screen` (lifetime metrics, read-only), `mascot_wardrobe_screen`, `perks_screen`, `friend_compare_screen` (local-only, encode/decode a friend code — no backend), `ghost_replay_screen` (paste a replay/challenge code, auto-plays it read-only), `leaderboard_screen` (offline, static bot datasets).

#### Widgets (`lib/presentation/widgets/`)
Core: `neon_button`, `neon_dialog`, `neon_app_bar`, `neon_bg`, `coin_chip`, `neon_icon`, `stroke_text`, `confetti_overlay`.
Also: shader/particle layers (`ambient_particles`, `ambient_weather_layer`, `aurora_bg_layer`, `neon_aura_layer`, `pulse_glow`, `coin_fly_overlay`), cosmetic/reward dialogs (`board_frame_picker_dialog`, `burst_style_picker_dialog`, `combo_text_style_picker_dialog`, `login_streak_dialog`, `spin_wheel_dialog`, `weekly_goal_dialog`, `prestige_action`), and small reusables (`home_carousel`, `pressable_scale`, `star_mascot`).

#### Registration
Permanent singletons are registered in `main.dart` via `Get.put(..., permanent: true)`: `StorageService`, `LocaleService`, `GameController`, `AudioManager`. Per-screen controllers (`GameScreenController`, `BossRushController`, `HomeScreenController`) are `Get.put` in their screen's `build`/`onInit` and deleted on exit.

## Meta-progression & side modes

### `GameMode` (on `GameController`)
```
campaign | timeAttack | zen | endless | dailyChallenge | puzzleLab | bossRush | mirrorMode | gauntlet | weeklyFeatured
```
- **campaign** — the 220-level story. `startLevel(id)`; positive level IDs index directly into `kLevels`.
- **timeAttack** — 60s countdown, pure score race, own `timeAttackBest`.
- **zen** — the one mode with `refillEnabled: true` (board refills, no timer, no rewards) — everywhere else in this codebase "no refill" is a hard invariant, don't assume it globally.
- **endless** — sequential boards of increasing difficulty (`advanceEndlessBoard`), cumulative score, `endlessBest`.
- **dailyChallenge** — deterministic seeded board (`daily_challenge.dart`), same for all players that day, one score/day.
- **puzzleLab** — plays a player-authored board (`startPuzzleLevel(grid)`); synthetic `PopLevel` with id `-5`; no coins/stars/unlock (pure sandbox).
- **bossRush** — sequence of boss encounters (`BossRushController`); combo persists across stages; bomb/shuffle/hint disabled.
- **mirrorMode** — symmetric board (`mirror_board.dart`), fixed level, own `mirrorModeBest`.
- **gauntlet** — Daily Challenge board + a daily rotating modifier (`gauntlet_modifiers.dart`, e.g. shortened combo window, undo disabled).
- **weeklyFeatured** — replays a deterministically-picked past campaign level each week; doesn't touch campaign progress.

**Side-mode levels use negative/synthetic IDs** to avoid colliding with campaign's positive `kLevels` IDs (Puzzle Lab = `-5`; others use fixed synthetic `PopLevel`s or on-the-fly generation) — do not assume every `PopLevel` in flight came from `kLevels`. Each non-campaign mode persists its own best/score key; they do not share `highScore`/`star`.

### Other systems living on `GameController`
- **Prestige / New Game+** — replay all 220 levels at a scaled target (`prestigeTier`, `prestigeTargetScore()`), +1000 coins per prestige.
- **Achievements** — evaluated in `_checkAchievements()` against `lib/data/achievements.dart`; vanity-only, coins on unlock, no gameplay effect.
- **Weekly goal** — cumulative gem-pop count across *every* mode (`registerPop()`), 300/week, 100 coins once claimed.
- **Daily reward streak** vs **daily spin wheel** — two *separate* systems, don't conflate them: `dailyStreak`/`claimDaily()` is a 1-7 day escalating coin streak; `todaySpinReward`/`claimSpin()` is an independent once-a-day wheel (coins or a booster) seeded by the date so the outcome is fixed for the whole day.
- **Login streak calendar** — separate again from both of the above; consecutive-real-day tracking with day 3/5/7 bonuses.
- **Comeback bonus** — one-time grant if the player was away ≥3 days.
- **Season pass** — 28-day free-track-only point ladder from campaign wins.
- **Cosmetics** (mascot skins, board frames, burst styles, combo-text styles) — unlocked by coins, prestige tier, or achievement thresholds; purely visual.
- **Clan system is a UI stub, not a real feature** — `app_translations.dart` has clan-related translation keys and there's clan-goal-hint UI copy, but there is **no** dedicated clan logic/data file, no backend, no per-member state. Don't extend it as if a clan backend exists; if asked to build clan features, that's new work, not a bug fix.

The full backlog for all of this (99 task files across `A#`/`F#`/`G#`/`I#`/`T#`/`X#` series, highest is `I54`) lives under `doc/task/tasks/`; `doc/task/backlog.md` only tracks the 5 top-level epics (E1-E5), not per-feature status — check the individual task file for a given `I#`/`F#` feature rather than assuming backlog.md is exhaustive.

## Key Conventions

### Storage
All SharedPreferences keys live in `StorageKeys` (`lib/core/storage_service.dart`) — never use string literals. Per-level keys are helpers: `highScore(id)`, `star(id)`. Each side mode/meta system has its own key(s) (e.g. `timeAttackBest`, `weeklyGoalProgress`, `dailyStreak`, `prestigeTier`) — follow that pattern for new state rather than overloading an existing key. `StorageService.to` is the singleton getter.

### Reactive unlock / async end
`unlockedLevel` is an observable on `GameController` so `LevelSelect` refreshes the moment a level is won. Level end is emitted through `gameCtrl.ended` (an `Rx<bool>`) because it happens after the Flame animation completes — consumers must observe it, not poll after a tap.

### Target achievability
Because campaign boards never refill (Zen is the sole exception), a level is only winnable if `targetScore` is reachable from the finite starting cells. Keep `targetScore` anchored to cell count (`cells * 6 * ramp`) — do not switch to level-index-linear scaling (it made most levels impossible; see `doc/feat.md`).

### Dialog pattern
Full-screen Flame app: `Get.dialog` and `showDialog` are no-ops (can't push a route over the `GameWidget`). Always render dialogs as in-tree overlays via `NeonDialog.show(...)`/`NeonDialog.overlay(panel: ...)` above the `GameWidget`.

### i18n
Translations live in `AppTranslations` (`lib/core/app_translations.dart`, ~29k lines — the largest file in the repo), 22 supported locales (`AppTranslations.supported`). New keys go into the English base map (fallback) and per-language override maps. The test `app_translations_test.dart` enforces every language has the full key set.

### Debug Logging
Use `dlog('message')` from `lib/core/debug_log.dart`. No-ops in release builds (tree-shaken). All debug prints are prefixed `roy93~` for easy logcat filtering.

### Theme
`NeonTheme` (`lib/core/neon_theme.dart`) was pivoted to a **bright-casual (Candy-Crush-style)** look: light candy-sky gradient background, tokens `ink`/`inkSoft` (text), `card`/`cardAlt` (panels), and `glow(...)` / `drop(...)` shadow helpers over a candy color palette.
