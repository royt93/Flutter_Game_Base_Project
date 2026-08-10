# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Pop Star Blast** — a tap-to-pop puzzle game (Flutter + GetX + Flame). Package: `com.galaxyjoy.pop_star_blast` (Android), `com.galaxyjoy.popStarBlast` (iOS). Font: Baloo2.

Core loop: a 260-level campaign (13 worlds × 20 levels, `lib/data/worlds.dart`) with a coin shop and boosters (bomb / shuffle / undo / rainbow / swap / freeze). Around that core, `GameController` also drives **14 side game modes** (time attack, zen, endless, daily challenge, puzzle lab, boss rush, mirror mode, gauntlet, weekly featured, pass-and-play, treasure map, remix, combo rush, frost rush — see `GameMode` enum below) plus a wide layer of meta-progression: prestige/New Game+, achievements, daily quests, weekly goals, login streaks, a season pass, clan-lite, star pets, constellations, pigments, cosmetics (mascot skins, board frames, burst styles, combo-text styles), and social-lite features (challenge codes, ghost replay, offline leaderboards). None of this meta layer has a real backend — it's all local `SharedPreferences` state; see "Meta-progression & side modes" below before assuming a system is more connected than it is.

Feature work is tracked as numbered task specs (`F#`/`I#`/`G#`/`A#`/`T#`/`X#`) under `doc/task/tasks/`, and **source comments cite those IDs** (`/// I65 Star Pet…`, `// I72 Milestone Journal…`). When a comment names a task ID, that file is the authoritative spec for the behaviour.

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

Tests (118 files) mirror the source layout: `test/logic`, `test/data`, `test/game`, `test/core`, `test/core/utils`, `test/presentation`, `test/widget` (+ `test/widget/goldens`), `test/tool`. Pure-logic changes should land a `test/logic` or `test/data` test — that layer is deliberately Flutter-free so it needs no widget harness.

## Architecture

The codebase has 4 layers with strict separation:

### 1. Pure Dart Logic (`lib/logic/`)
No Flutter, no Flame, no GetX. Fully unit-testable in isolation. The grid is `List<List<int?>>` (color index ≥0, or a negative sentinel for a special tile, or `null` for an empty cell).

**Negative-ID map — every special tile owns a disjoint band. Check it before adding a new tile type:**

| Band | Tile | Constant |
|---|---|---|
| `-1..-9` | obstacle (durability = `-d`) | `obstacle.dart` |
| `-500` | wildcard | `wildcardTileValue` |
| `-700..-799` | magnet (`-700 - colorIndex`) | `magnetTileIdBase` |
| `-1000` | gift | `giftTileValue` |
| `-1400..-1401` | ice (2 layers) | `iceTileIdBase` |
| `-1500..` | countdown lock | `countdownLockIdBase` |
| `≤ -2000` | boss region | `bossTileIdBase` |

- **`pop_detector.dart`** — `findConnectedGroup(grid, row, col)`: flood-fill (4-directional) of same-color adjacent cells (respects `lockGrid` for chain tiles; wildcard tiles match any color but don't bridge two different-color groups). `findLargestGroup()` scans for hint purposes. `hasAnyMovableGroup(grid)`: stuck-board detection.
- **`pop_collapse.dart`** — `applyGravityAndCollapse(grid)`: gravity within each column, then empty columns collapse left. Generic across 4 gravity directions (`GravityDirection`, a per-level property) via coordinate transform. **No refill** in campaign — the board only drains (Zen mode is the one exception, see below). Keeps a parallel `lockGrid` in sync for chain tiles.
- **`obstacle.dart`** — obstacles encode as negative durability (`-d`); adjacent pops chip 1 durability, breaking at 0.
- **`boss_tile.dart`** — boss tiles occupy a rectangular region sharing one ID (≤ -2000); HP lives in a separate `Map<int,int>` keyed by ID, not in the grid. Distinct from `PopLevel.isBoss` (that just scales target score).
- **`gift_tile.dart`** — gift tiles (`-1000`) auto-open when they reach the bottom row, yielding a random `GiftReward` (coins/bomb/shuffle/undo).
- **`wildcard_tile.dart`** — wildcard tiles (`-500`) match any color in flood-fill; tapped directly, they inherit a neighbor's color.
- **`power_tile.dart`** — pops of size 5-6/7-8/≥9 spawn a line/bomb/rainbow power tile (`powerTileKindForGroupSize`).
- **`chain_tile.dart`** — real-colored tiles locked for K adjacent pops, tracked via the parallel `lockGrid`.
- **`countdown_lock_tile.dart`** — counts down 1 per tap anywhere on the board, then converts to a plain obstacle.
- **`ice_tile.dart`** — 2-layer ice obstacle on its own ID band (**not** durability-encoded like `obstacle.dart`, deliberately, so it can't collide with real obstacle durability). `chipAdjacentIceTiles` mirrors `chipAdjacentObstacles` but matches by `isIceTileId` instead of excluding other tile types one by one — note `chipAdjacentObstacles` itself is missing a magnet check.
- **`magnet_tile.dart`** — color-bound tile; popping that color anywhere on the board triggers it for bonus score.
- **`boss_skill.dart`** — pure boss-skill spec (`freezeRandomCells` / `spawnObstacle`) firing every N moves, seeded so it's deterministic.
- **`time_freeze_tile.dart`** — pure predicate tagging a cell with a Time Attack time-freeze bonus.
- **`daily_challenge.dart`** — `generateDailyChallengeGrid()`: seeded-by-epoch-day board, identical for every player that day; reused by Gauntlet.
- **`leaderboard.dart`** — offline leaderboard simulation: merges a static bot list with the player's score, sorts, ranks. No network.
- **`milestone_journal.dart`** — collapses timestamped milestones scattered across `GameController` into one sorted feed. Pure: takes raw values as parameters, reads no `StorageService`/GetX.
- **`mystery_crate.dart`** — thin read-only wrapper enumerating all 4 cosmetic systems as `CosmeticEntry`. Does **not** unify their 4 different unlock patterns.
- **`pass_and_play.dart`** — 2-player hot-seat turn/outcome resolution on one shared source board.
- **`login_streak.dart`**, **`craft_points.dart`**, **`replay.dart`** (deterministic seed+taps replay, campaign-only), **`challenge_code.dart`** (peer score-only challenge), **`puzzle_code.dart`** (Puzzle Lab board encode/decode), **`backup_code.dart`** (AES-GCM encrypted save backup) — self-contained, see file docs.

### 2. Data / Config (`lib/data/`)
- **`levels.dart`** — `PopLevel`, `kLevels` (260 entries via `List.generate`), `kLevelCount = 260`. `scoreForGroup(n) = 5*n*(n-1)`. Difficulty ramps every 20 levels (rows 8..11, cols 6..12, colors 4..7). `targetScore` anchors to `cells * 6 * ramp` (ramp = `1 + world*0.03`) — see "Target achievability" below, this constraint still holds. Also owns every **side-mode synthetic `PopLevel`** (negative IDs, see mode table below) and the `_sideModeLevel(id)` helper (shared 9×8 / 5-color board for time attack, zen, combo rush, frost rush — those modes' actual rules live in controller/UI, not here). Some doc comments in this file still say "200 màn"/"220 level" — stale, `kLevelCount` is the truth.
- **`worlds.dart`** — 13 worlds (20 levels each, `startId`/`endId` inclusive) with name key/color/icon/`WeatherKind`.
- **`weekly_goal.dart`** — fixed 300-gem weekly target, cumulative across *all* modes, resets on week boundary. Owns `weekIndexForEpochDay`, which clan-lite reuses — don't redefine week math elsewhere.
- **`achievements.dart`** — 28 vanity-only achievements (`AchievementMetric` × tiers) over lifetime metrics; coin reward, one-time unlock, no gameplay effect.
- **`board_frames.dart`**, **`burst_styles.dart`**, **`combo_text_styles.dart`**, **`mascot_skins.dart`** — 4 *separate* cosmetic unlock tables with 4 different gating patterns (coins, prestige tier, achievement thresholds). They are intentionally not unified; `mystery_crate.dart` only reads across them.
- **`combo_milestones.dart`** — fixed combo breakpoints (5/10/15/20) for VFX/haptics.
- **`perks.dart`** — permanent per-world-completion unlocks (extra undo, hint, coin bonus); pick up to 2 active.
- **`boss_rush.dart`** — generates Boss Rush stages on the fly from already-unlocked world geometry, 5%/stage scaling.
- **`mirror_board.dart`** — symmetric board generator for Mirror Mode.
- **`gauntlet_modifiers.dart`** — one modifier type (`GauntletModifier`: colorCount / gravity override, combo-window and booster restrictions) reused by **three** modes via separate const lists: `kGauntletModifiers` (daily), `kTreasureMapModifiers` (per-stage), `kRemixLevels` (campaign level + modifier pairs).
- **`clan.dart`** — clan-lite: one fixed clan, 6 static NPC names, seeded weekly bot contributions, 2000-gem shared pool. Fully local, no backend, no clan selection/creation.
- **`daily_quests.dart`** — 3 quests picked deterministically per epoch-day from `kDailyQuestPool`, independent progress/claim each.
- **`star_pets.dart`** — pet types reusing `MascotPalette` from `mascot_skins.dart` (no separate color table); hatched with the **Star Dust** currency, not coins.
- **`pigments.dart`** — Color Alchemy palette; each pigment is free, coin-priced, **or** achievement-gated (asserted mutually exclusive).
- **`constellations.dart`** — Sky Shrine constellation specs.
- **`lucky_color.dart`**, **`weekly_featured.dart`** — deterministic per-day/per-week pickers (epoch-seeded, same for every player).
- **`*_leaderboard_bots.dart`** (daily challenge / gauntlet / weekly featured / generic) — static bot score tables feeding the offline leaderboard.

### 3. Flame Engine (`lib/game/`)
- **`pop_star_game.dart`** — main `FlameGame`. Owns `colorGrid` (source of truth) and `_blocks` (`BlockComponent` per cell). Flow: tap → `_tryPop` finds the group → score → `_clearAndCollapse` animates a pop burst (scale + particles), then `_collapseAnimated` tweens columns/blocks into place. `_animating` locks input during animation. `backgroundColor()` is transparent so the candy background shows through. Boosters operate directly on the grid: `triggerBomb(r,c)`, `shuffleBoard()`, `undo()` (single-step snapshot), plus rainbow/swap/freeze. `_checkEnd()` calls `controller.checkEnd(cleared)` when the board is empty or stuck. Tap comes from a `GestureDetector` in `game_screen.dart` via `handleTap` (not Flame's TapDetector). Same engine instance is reused for every `GameMode` — mode-specific rules (refill, timer, modifiers) are parameters/flags passed in at start, not separate engines.
- **`block_component.dart`** — renders one gem (candy look) from its `colorIndex`, plus overlays for special tiles (obstacle/gift/boss/wildcard/chain/countdown/ice/magnet/power).

`pop_star_game.dart` is ~2.3k lines and holds mode-specific board setup too (e.g. `_placeForcedIceTiles` for Frost Rush reads `controller.mode`), so a "mode rule" may live in the engine rather than in `levels.dart` or a controller — grep all three.

### 4. GetX Presentation (`lib/presentation/`)

#### Controllers (`lib/presentation/controllers/`)
- **`game_controller.dart`** — single file, **no `part` splitting** (~2.6k lines — the biggest single source of truth in the app; read it in full before making cross-cutting changes). Holds reactive campaign state (`score`, `coins`, `starsEarned`, `ended`, `cleared`, `currentLevelRx`, `unlockedLevel`), booster counts/prices, and **all** meta-progression state (prestige, achievements, daily quests, weekly goal, clan contribution, daily reward + daily spin, login streak, season pass, star pets/Star Dust, constellations, pigments, cosmetics, per-mode best scores). See "Meta-progression & side modes" below for the `GameMode` system it drives.
  - `_load()` **re-validates every persisted id** against the current const tables (skins, pets, frames, burst/combo styles, titles, achievements) and silently drops ids that no longer exist. Keep that pattern when adding a new persisted-id system — removing an entry from a const table must not corrupt a save.
- **`game_screen_controller.dart`** — drives `GameScreen`. `GameUi` enum: `playing | quit | win | lose`. `BoosterMode` enum: `none | bomb`. Level end is **asynchronous** (fires after the pop/fall animation), so it listens reactively via `ever(gameCtrl.ended, ...)` rather than checking right after a tap. Manages wakelock, the Flame game instance, `again`/`next`/`quit`.
- **`boss_rush_controller.dart`** — orchestrates a single Boss Rush run (stage progression, lives, best streak) separately from `GameController` to avoid a circular dependency; `PopStarGame` calls `advanceStage()` on win, keeping the same engine instance across stages so combo/score chain.
- **`pass_and_play_controller.dart`**, **`treasure_map_controller.dart`**, **`raid_boss_controller.dart`** — same pattern as `BossRushController`: each owns one run's orchestration, holds a `GameController` reference, and observes `ever(gameCtrl.ended, …)` instead of being called back synchronously. `raid_boss_controller.dart` also holds the weekend-window predicate (`isRaidActiveForEpochDay`, Fri–Sun) and the damage reward tiers.
- **`home_screen_controller.dart`** — builds the home screen's progress-carousel card list (`buildHomeCards`), refreshed on resume so it reflects state changed on other screens.

#### Screens (`lib/presentation/screens/`)
Core: `home_screen`, `mode_select_screen` (entry point to the side modes), `level_select_screen` (260-level grid), `game_screen`, `shop_screen`, `guide_screen`, `settings_screen`. `GameScreen` is driven entirely by `GameScreenController`.
Modes/meta: `boss_rush_screen`, `raid_boss_screen`, `puzzle_lab_screen` (in-app level editor, saves up to 5 boards locally, share via `puzzle_code.dart`), `season_screen` (28-day free season pass), `star_road_screen`, `sky_shrine_screen` (constellations), `color_alchemy_screen` (pigments), `pet_habitat_screen` (star pets), `sticker_album_screen` (cosmetic-count milestones), `board_frame_screen`, `mascot_wardrobe_screen`, `achievements_screen`, `trophy_room_screen` (read-only), `stats_screen` (read-only), `milestone_journal_screen`, `perks_screen`, `friend_compare_screen` (local-only friend code — no backend), `ghost_replay_screen` (paste a replay/challenge code, auto-plays read-only), `leaderboard_screen` (offline, static bot datasets).

> Some pickers migrated from dialog to full-screen route when their list outgrew a dialog (e.g. `board_frame_screen` replaced the old board-frame dialog). Both forms still exist side by side — check which one a given cosmetic uses before wiring UI.

#### Widgets (`lib/presentation/widgets/`)
Core: `neon_button`, `neon_dialog`, `neon_app_bar`, `neon_bg`, `coin_chip`, `neon_icon`, `stroke_text`, `confetti_overlay`, `score_card`.
Also: shader/particle layers (`ambient_particles`, `ambient_weather_layer`, `aurora_bg_layer`, `neon_aura_layer`, `pulse_glow`, `coin_fly_overlay`), dialogs (`burst_style_picker_dialog`, `combo_text_style_picker_dialog`, `login_streak_dialog`, `spin_wheel_dialog`, `weekly_goal_dialog`, `daily_quest_dialog`, `mystery_crate_dialog`, `clan_dialog`, `prestige_action`), and small reusables (`home_carousel`, `pressable_scale`, `star_mascot`, `mascot_skin_tile`, `star_pet_habitat`).

#### Registration
Permanent singletons are registered in `main.dart` via `Get.put(..., permanent: true)`: `StorageService`, `LocaleService`, `GameController`, `ReminderService`, `AudioManager` (audio is put last / conditionally — see `RuntimeFlags` + the `E2E_TEST` note under Commands). Per-run controllers (`GameScreenController`, `BossRushController`, `PassAndPlayController`, `TreasureMapController`, `RaidBossController`, `HomeScreenController`) are `Get.put` in their screen's `build`/`onInit` and deleted on exit.

#### Core services (`lib/core/`, `lib/core/utils/`)
`storage_service` (all keys), `app_translations`, `locale_service`, `audio_manager`, `haptics`, `neon_theme`, `debug_log`, `app_info`, `runtime_flags` (E2E/test toggles), `reminder_service` (local notifications), `home_widget_sync` (pushes coins + login streak to the OS home widget on change), `share_helper`. Utils: `format`, `friend_code`, `comeback_bonus`, `weekend_event`.

## Meta-progression & side modes

### `GameMode` (on `GameController`)
```
campaign | timeAttack | zen | endless | dailyChallenge | puzzleLab | bossRush | mirrorMode
| gauntlet | weeklyFeatured | passAndPlay | treasureMap | remixLevel | comboRush | frostRush
```
- **campaign** — the 260-level story. `startLevel(id)`; positive level IDs index directly into `kLevels`.
- **timeAttack** (`-1`) — 60s countdown, pure score race, own `timeAttackBest`.
- **zen** (`-2`) — the one mode with `refillEnabled: true` (board refills, no timer, no rewards) — everywhere else in this codebase "no refill" is a hard invariant, don't assume it globally.
- **endless** (`-3`) — sequential boards of increasing difficulty (`endlessLevelForIndex`, continuous ramp with clamped ceiling, no world split), cumulative score, `endlessBest`.
- **dailyChallenge** (`-4`) — deterministic seeded board (`daily_challenge.dart`), same for all players that day, one score/day.
- **puzzleLab** (`-5`) — plays a player-authored board (`startPuzzleLevel(grid)`); no coins/stars/unlock (pure sandbox).
- **mirrorMode** (`-6`) — symmetric board (`mirror_board.dart`), fixed level, own `mirrorModeBest`.
- **gauntlet** (`-7`) — Daily Challenge board + a daily rotating modifier (`kGauntletModifiers`, e.g. shortened combo window, undo disabled).
- **comboRush** (`-8`) — no timer; the race is holding a combo chain. Rules live in controller/UI, the `PopLevel` only sizes the board.
- **frostRush** (`-9`) — forced high ice-tile density, injected by `PopStarGame._placeForcedIceTiles` reading `controller.mode`, **not** by the `PopLevel`.
- **bossRush** — sequence of boss encounters (`BossRushController`); combo persists across stages; bomb/shuffle/hint disabled.
- **weeklyFeatured** — replays a deterministically-picked past campaign level each week; doesn't touch campaign progress.
- **remixLevel** — replays an existing campaign level with a `GauntletModifier` applied. `remixLevelFor` **keeps the base level's id** (unlike other side modes) but does not write per-id `highScore`/`star`.
- **treasureMap** — multi-stage expedition, one `kTreasureMapModifiers` entry per stage; consumes a map item (`consumeTreasureMap()`).
- **passAndPlay** — 2-player hot seat on one source board: the board is immutable-by-convention with a per-turn deep copy.

**Side-mode levels use negative/synthetic IDs** to avoid colliding with campaign's positive `kLevels` IDs — do not assume every `PopLevel` in flight came from `kLevels`. Each non-campaign mode persists its own best/score key; they do not share `highScore`/`star`. Raid Boss is driven by `RaidBossController` and is **not** a `GameMode` value.

### Other systems living on `GameController`
- **Prestige / New Game+** — replay all campaign levels at a scaled target (`prestigeTier`, `prestigeTargetScore()`), +1000 coins per prestige. No new levels are generated.
- **Achievements** — evaluated in `_checkAchievements()` against `lib/data/achievements.dart`; vanity-only, coins on unlock, no gameplay effect. High tiers can auto-unlock the mascot skin bound to them (free).
- **Weekly goal** vs **clan contribution** — both count gem pops per week and are incremented side by side, but they are **separate counters with separate targets** (300 personal / 2000 clan pool). Both use `weekIndexForEpochDay`.
- **Daily quests** — 3 quests per epoch-day from `kDailyQuestPool`, independent progress/claim. Separate from the weekly goal.
- **Daily reward streak** vs **daily spin wheel** — two *separate* systems, don't conflate them: `dailyStreak`/`claimDaily()` is a 1-7 day escalating coin streak; `todaySpinReward`/`claimSpin()` is an independent once-a-day wheel (coins or a booster) seeded by the date so the outcome is fixed for the whole day.
- **Login streak calendar** — separate again from both of the above; consecutive-real-day tracking with day 3/5/7 bonuses, plus a purchasable streak-protection token sold like a booster.
- **Comeback bonus** — one-time grant if the player was away ≥3 days.
- **Season pass** — 28-day free-track-only point ladder from campaign wins.
- **Star pets** — hatched with **Star Dust**, a currency separate from coins, earned on every 3-star campaign win.
- **Color Alchemy (pigments)**, **Sky Shrine (constellations)**, **Sticker Album** (milestones on *total* cosmetics owned across all 4 systems), **Milestone Journal** (unified feed) — all local, all cosmetic/vanity.
- **Cosmetics** (mascot skins, board frames, burst styles, combo-text styles) — 4 independent tables with different unlock gates; purely visual.
- **Clan is "clan-lite", not a social backend** — `lib/data/clan.dart` is real code, but it is one hard-coded clan with 6 NPC names and seeded weekly bot contributions. No clan creation/joining, no membership state, no network. Building actual multi-user clans is new work, not a bug fix.
- **Weekend events / Raid Boss** — gated on real weekday (`weekend_event.dart`, `isRaidActiveForEpochDay` = Fri–Sun). Time-dependent tests must inject an epoch day, not read the clock.

The full backlog (117 task files across `A#`/`F#`/`G#`/`I#`/`T#`/`X#` series, highest `I80` / `X9`) lives under `doc/task/tasks/`; `doc/task/backlog.md` only tracks the top-level epics, not per-feature status — check the individual task file for a given `I#`/`F#` feature rather than assuming backlog.md is exhaustive.

## Key Conventions

### Storage
All SharedPreferences keys live in `StorageKeys` (`lib/core/storage_service.dart`, ~80 keys) — never use string literals. Per-level keys are helpers: `highScore(id)`, `star(id)`. Each side mode/meta system has its own key(s) (e.g. `timeAttackBest`, `weeklyGoalProgress`, `dailyStreak`, `prestigeTier`) — follow that pattern for new state rather than overloading an existing key. `StorageService.to` is the singleton getter. Anything storing an **id from a const table** must be re-validated on load (see `_load()` in `GameController`).

### Reactive unlock / async end
`unlockedLevel` is an observable on `GameController` so `LevelSelect` refreshes the moment a level is won. Level end is emitted through `gameCtrl.ended` (an `Rx<bool>`) because it happens after the Flame animation completes — consumers must observe it, not poll after a tap.

### Target achievability
Because campaign boards never refill (Zen is the sole exception), a level is only winnable if `targetScore` is reachable from the finite starting cells. Keep `targetScore` anchored to cell count (`cells * 6 * ramp`) — do not switch to level-index-linear scaling (it made most levels impossible; see `doc/feat.md`).

### Dialog pattern
Full-screen Flame app: `Get.dialog` and `showDialog` are no-ops (can't push a route over the `GameWidget`). Always render dialogs as in-tree overlays via `NeonDialog.show(...)`/`NeonDialog.overlay(panel: ...)` above the `GameWidget`.

### i18n
Translations live in `AppTranslations` (`lib/core/app_translations.dart`, ~33k lines — by far the largest file in the repo), 22 supported locales (`AppTranslations.supported`). New keys go into the English base map (fallback) and per-language override maps. The test `app_translations_test.dart` enforces every language has the full key set — adding one key means adding 22 entries.

### Determinism
Anything "same for every player" (daily challenge board, gauntlet/treasure-map modifiers, lucky color, weekly featured level, daily quests, spin result, clan bot contributions, boss skills) is a `Random(seed)` derived from epoch-day or week-index — never `DateTime.now()` inside the generator, and never a global RNG. Keep new shared content on that pattern so it stays reproducible in tests.

### Debug Logging
Use `dlog('message')` from `lib/core/debug_log.dart`. No-ops in release builds (tree-shaken). All debug prints are prefixed `roy93~` for easy logcat filtering.

### Theme
`NeonTheme` (`lib/core/neon_theme.dart`) was pivoted to a **bright-casual (Candy-Crush-style)** look: light candy-sky gradient background, tokens `ink`/`inkSoft` (text), `card`/`cardAlt` (panels), and `glow(...)` / `drop(...)` shadow helpers over a candy color palette.
