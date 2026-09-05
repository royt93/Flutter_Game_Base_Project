# Strip Pop Star Blast to "Roy Project Base Game" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this repo, in place, from the Pop Star Blast match-3 game into a lean, generic Flutter+GetX+Flame starting point ("Roy Project Base Game") that future game projects can copy — by deleting every match-3/meta-progression-specific file and rewriting the handful of entry-point files that touched them.

**Architecture:** Keep the existing 4-layer split (`lib/core`, `lib/data`, `lib/game`, `lib/presentation`) as the pattern, but empty `lib/logic` and `lib/data` entirely (no game-specific pure-Dart logic ships in the base) and reduce `lib/game`/`lib/presentation` to nothing beyond a boot screen + settings screen exercising the kept core services. No new abstractions are introduced — this is subtraction plus three small rewrites (`app_translations.dart`, `reminder_service.dart`, `main.dart`), not a redesign.

**Tech Stack:** Flutter, GetX (`get`), Flame (`flame`, `flame_audio`), `shared_preferences`, `flutter_local_notifications` + `timezone`, `share_plus`, `wakelock_plus`, `package_info_plus`.

**Spec:** Decided inline in conversation (no separate spec doc — a spec file restating this plan would be redundant). Summary of user decisions this plan implements:
1. Strip everything match-3/meta-specific; keep only the generic core (chosen over "keep Pop Star Blast as an example game").
2. Full rename: Dart package name, Android applicationId/namespace, iOS bundle id, app display name, README/CLAUDE.md — not just cosmetic display name.
3. Safety net: **already done** — `git remote add origin https://github.com/royt93/Flutter_Game_Base_Project.git` and `git push -u origin main` ran before this plan was written, so the full Pop Star Blast history is preserved on `origin/main` regardless of what this plan deletes locally (nothing here rewrites git history).

## Global Constraints

- New Dart package name: `roy_base_game` (must stay `lowercase_with_underscores` — Dart package name rules).
- New Android `namespace`/`applicationId`: `com.galaxyjoy.roybasegame`.
- New iOS `PRODUCT_BUNDLE_IDENTIFIER`: `com.galaxyjoy.royBaseGame` (matches the existing camelCase-on-iOS/snake_case-on-Android split already used by `pop_star_blast`/`popStarBlast`).
- New app display name (Android label, iOS `CFBundleDisplayName`, `GetMaterialApp.title`): `Roy Project Base Game`.
- `flutter analyze` must report 0 issues at the end of every task below (repo convention, `CLAUDE.md`).
- Do not touch `.git` history-rewriting commands (no `reset --hard`, no force-push) — every change lands as normal commits; `origin/main`'s pre-strip snapshot is the rollback path if something is wrong.
- Every task ends with a build/analyze/test command that must pass before moving to the next task — no red state committed.

---

### Task 1: Delete match-3 pure logic + data + Flame engine, and their tests

**Files:**
- Delete directory: `lib/logic/` (31 files — pop/collapse/obstacle/boss/gift/wildcard/chain/ice/magnet/countdown/power/time-freeze tiles, daily challenge, leaderboard, milestone journal, mystery crate, pass-and-play, login streak, craft points, replay, challenge/puzzle/backup code, ghost duel, mirror draft, next action, second chance, comeback digest, ftue tips, puzzle daily)
- Delete directory: `lib/data/` (24 files — levels, worlds, achievements, cosmetics tables, pigments, constellations, star pets, clan, daily quests, gauntlet modifiers, all `*_leaderboard_bots.dart`, weekly goal/featured, perks, combo milestones, puzzle presets)
- Delete directory: `lib/game/` (`pop_star_game.dart`, `block_component.dart` — the match-3 Flame engine)
- Delete directory: `test/logic/` (34 files, mirrors `lib/logic/`)
- Delete directory: `test/data/` (22 files, mirrors `lib/data/`)
- Delete directory: `test/game/` (6 files, mirrors `lib/game/`)
- Delete: `test/widget/goldens/block_component_material_golden_test.dart` and its 3 `block_material_*.png` fixtures (golden test for the deleted `block_component.dart`)
- Delete: `test/tool/campaign_total_sweep_test.dart` (sums campaign target scores — campaign no longer exists)

**Interfaces:** None — this task only deletes, nothing downstream depends on these directories being present yet (Task 2 removes the last callers).

- [ ] **Step 1: Delete the directories and stray files**

```bash
git rm -r lib/logic lib/data lib/game test/logic test/data test/game
git rm test/widget/goldens/block_component_material_golden_test.dart \
       test/widget/goldens/block_material_crystal.png \
       test/widget/goldens/block_material_jelly.png \
       test/widget/goldens/block_material_metal.png \
       test/tool/campaign_total_sweep_test.dart
```

- [ ] **Step 2: Confirm nothing outside the deleted trees imports them yet**

Run: `grep -rn "^import '.*\(logic\|data\|game\)/" lib | grep -v "^lib/core\|^lib/presentation"`

Expected: matches only inside `lib/presentation/` (controllers/screens/widgets) — those callers are deleted in Task 2, so leave them broken for now. Do not fix them here.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: strip match-3 game logic, data tables, and Flame engine"
```

---

### Task 2: Delete side-mode controllers, screens, and PSB-specific widgets

**Files:**
- Delete: `lib/presentation/controllers/*.dart` (all 7: `boss_rush_controller.dart`, `game_controller.dart`, `game_screen_controller.dart`, `home_screen_controller.dart`, `pass_and_play_controller.dart`, `raid_boss_controller.dart`, `treasure_map_controller.dart`)
- Delete: `lib/presentation/screens/*.dart` (all 25 files — including `home_screen.dart` and `settings_screen.dart`; both get a fresh minimal replacement in Task 4, not a rewrite of the old file)
- Delete these 19 PSB-specific widgets from `lib/presentation/widgets/`: `burst_style_picker_dialog.dart`, `clan_dialog.dart`, `coin_fly_overlay.dart`, `combo_text_style_picker_dialog.dart`, `daily_quest_dialog.dart`, `home_carousel.dart`, `journey_card.dart`, `login_streak_dialog.dart`, `mascot_skin_tile.dart`, `mystery_crate_dialog.dart`, `next_up_bar.dart`, `prestige_action.dart`, `score_card.dart`, `spin_wheel_dialog.dart`, `star_mascot.dart`, `star_pet_habitat.dart`, `token_chip.dart`, `weekly_goal_dialog.dart`
- **Keep** these 13 generic widgets untouched: `ambient_particles.dart`, `ambient_weather_layer.dart`, `aurora_bg_layer.dart`, `coin_chip.dart`, `confetti_overlay.dart`, `neon_app_bar.dart`, `neon_aura_layer.dart`, `neon_bg.dart`, `neon_button.dart`, `neon_dialog.dart`, `neon_icon.dart`, `pressable_scale.dart`, `pulse_glow.dart`, `stroke_text.dart`
- Delete: `test/presentation/*.dart` (all 20 files — controller/wiring tests for the deleted controllers)
- Delete: `test/widget/*.dart` except goldens (all remaining files are screen/dialog tests for deleted screens/widgets: `achievements_screen_test.dart` through `world_rule_banner_test.dart` — every file in `test/widget/` whose name matches a deleted screen or deleted widget)
- Delete: `test/widget/goldens/*` for deleted widgets — none remain after Task 1's golden cleanup; the goldens for kept widgets (`coin_chip`, `neon_app_bar`, `neon_button`, `neon_icon`, `stroke_text`, `theme_dark_toggle`) stay
- Delete: `test/tool/i18n_hardcoded_test.dart`, `test/tool/rtl_direction_test.dart` (scan the now-deleted screen tree / old translation table — recreate later against the new minimal translations if needed)

**Interfaces:** None produced — Task 4 creates fresh `home_screen.dart`/`settings_screen.dart` from scratch, not by editing what Task 2 deletes.

- [ ] **Step 1: Delete controllers, screens, PSB widgets, and their tests**

```bash
git rm -r lib/presentation/controllers lib/presentation/screens
git rm lib/presentation/widgets/burst_style_picker_dialog.dart \
       lib/presentation/widgets/clan_dialog.dart \
       lib/presentation/widgets/coin_fly_overlay.dart \
       lib/presentation/widgets/combo_text_style_picker_dialog.dart \
       lib/presentation/widgets/daily_quest_dialog.dart \
       lib/presentation/widgets/home_carousel.dart \
       lib/presentation/widgets/journey_card.dart \
       lib/presentation/widgets/login_streak_dialog.dart \
       lib/presentation/widgets/mascot_skin_tile.dart \
       lib/presentation/widgets/mystery_crate_dialog.dart \
       lib/presentation/widgets/next_up_bar.dart \
       lib/presentation/widgets/prestige_action.dart \
       lib/presentation/widgets/score_card.dart \
       lib/presentation/widgets/spin_wheel_dialog.dart \
       lib/presentation/widgets/star_mascot.dart \
       lib/presentation/widgets/star_pet_habitat.dart \
       lib/presentation/widgets/token_chip.dart \
       lib/presentation/widgets/weekly_goal_dialog.dart
git rm -r test/presentation
find test/widget -maxdepth 1 -name "*_test.dart" ! -name "ambient_weather_layer_test.dart" \
  ! -name "aurora_bg_layer_test.dart" ! -name "confetti_overlay_test.dart" \
  ! -name "neon_aura_layer_test.dart" ! -name "neon_bg_test.dart" \
  ! -name "neon_dialog_test.dart" ! -name "pressable_scale_test.dart" \
  ! -name "pulse_glow_test.dart" -print0 | xargs -0 git rm
git rm test/tool/i18n_hardcoded_test.dart test/tool/rtl_direction_test.dart
```

Note: the `find` filter keeps widget tests for the 13 kept widgets that still have a standalone `*_test.dart` (as opposed to a golden test) — check the actual output list before it runs (`find ... -print0` without piping to `xargs` first) if unsure, since `test/widget/` mixes screen tests and widget tests in one flat directory.

- [ ] **Step 2: Verify no dangling imports remain outside `lib/core`**

Run: `grep -rln "presentation/controllers\|presentation/screens" lib/core lib/main.dart`

Expected: only `lib/main.dart` (fixed in Task 4).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: strip side-mode controllers, screens, and PSB-specific widgets"
```

---

### Task 3: Replace or trim the core services that referenced deleted code

**Context:** `app_translations.dart` (36k lines, 22 locales of PSB copy) and `reminder_service.dart` (imports `data/weekly_goal.dart` + the deleted `game_controller.dart`) cannot compile once Tasks 1–2 land. `storage_service.dart` and `audio_manager.dart` still compile (no deleted imports) but carry PSB-only keys/logic that a base project shouldn't ship. `home_widget_sync.dart` and three `core/utils/*.dart` files have no reason to exist in a base with no coins/streak system.

**Files:**
- Rewrite: `lib/core/app_translations.dart` (replace 22-locale PSB copy with 2 locales — `en`, `vi` — and ~6 seed keys)
- Rewrite: `lib/core/reminder_service.dart` (drop the 4-kind priority system tied to spin/streak/weekly-goal/quests; keep a minimal "schedule one local notification N hours out" API)
- Modify: `lib/core/storage_service.dart` (trim `StorageKeys` to 3 constants)
- Modify: `lib/core/audio_manager.dart` (drop per-level/per-combo BGM switching and the `notes` SFX table; keep init/play/pause/resume/mute over one bgm track)
- Delete: `lib/core/home_widget_sync.dart`, `lib/core/utils/comeback_bonus.dart`, `lib/core/utils/weekend_event.dart`, `lib/core/utils/friend_code.dart`
- Delete matching tests: `test/core/app_translations_test.dart`, `test/core/i18n_debt_test.dart`, `test/core/round9_i18n_test.dart`, `test/core/home_widget_sync_test.dart`, `test/core/reminder_service_test.dart`, `test/core/utils/comeback_bonus_test.dart`, `test/core/utils/weekend_event_test.dart`, `test/core/utils/friend_code_test.dart`
- Modify: `test/core/storage_service_test.dart` (drop assertions on removed keys)
- Keep untouched: `lib/core/app_info.dart`, `lib/core/debug_log.dart`, `lib/core/runtime_flags.dart`, `lib/core/haptics.dart`, `lib/core/locale_service.dart`, `lib/core/neon_theme.dart`, `lib/core/share_helper.dart`, `lib/core/utils/clamped_clock.dart`, `lib/core/utils/format.dart`, `lib/core/utils/label_fit.dart`, and their tests

**Interfaces:**
- Produces: `AppTranslations` (unchanged public shape — `GetX Translations` subclass, `static const supported`, `static const fallback`) so `main.dart` (Task 4) wires it in exactly as before.
- Produces: `ReminderService.scheduleNext()` / `ReminderService.cancel()` / `static ReminderService? get maybe` (same names `main.dart` already calls — see the current `lib/main.dart` calls `ReminderService.maybe?.scheduleNext()`).
- Produces: `StorageKeys.localeCode`, `StorageKeys.audioMuted`, `StorageKeys.themeDark` (the only 3 kept constants; Task 4's settings screen reads/writes exactly these).
- Produces: `AudioManager.init()`, `.startBgm()`, `.pauseBgm()`, `.resumeBgm()`, `.toggleMute()` / `.muted` (same names `main.dart` and the new settings screen call).

- [ ] **Step 1: Rewrite `lib/core/app_translations.dart`**

```dart
import 'package:get/get.dart';

/// Minimal seed translations for the base project — 2 locales, 6 keys.
/// Copy this file's pattern (one `Map<String,String>` per locale code) when
/// a new game needs more languages or more keys.
class AppTranslations extends Translations {
  static const supported = [Locale('en'), Locale('vi')];
  static const fallback = Locale('en');

  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'app_name': 'Roy Project Base Game',
      'settings': 'Settings',
      'language': 'Language',
      'sound': 'Sound',
      'ok': 'OK',
      'cancel': 'Cancel',
    },
    'vi': {
      'app_name': 'Roy Project Base Game',
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'sound': 'Âm thanh',
      'ok': 'Đồng ý',
      'cancel': 'Huỷ',
    },
  };
}
```

- [ ] **Step 2: Rewrite `lib/core/reminder_service.dart`**

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'debug_log.dart';

/// One local notification, scheduled a fixed delay out. Games that need
/// several reminder kinds/priorities should extend this, not add branches
/// here — keep the base's default path to exactly one notification.
class ReminderService extends GetxController {
  static ReminderService? get maybe =>
      Get.isRegistered<ReminderService>() ? Get.find<ReminderService>() : null;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<void> scheduleNext({
    Duration delay = const Duration(hours: 24),
    String title = 'Roy Project Base Game',
    String body = 'Come back and play!',
  }) async {
    try {
      await _ensureInit();
      await _plugin.zonedSchedule(
        0,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(delay),
        const NotificationDetails(
          android: AndroidNotificationDetails('reminders', 'Reminders'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      dlog('roy93~ ReminderService.scheduleNext failed: $e');
    }
  }

  Future<void> cancel() async {
    try {
      await _ensureInit();
      await _plugin.cancel(0);
    } catch (e) {
      dlog('roy93~ ReminderService.cancel failed: $e');
    }
  }
}
```

- [ ] **Step 3: Trim `lib/core/storage_service.dart`'s `StorageKeys`**

Read the file first, then replace the whole `StorageKeys` class body with:

```dart
class StorageKeys {
  StorageKeys._();

  static const String localeCode = 'locale_code';
  static const String audioMuted = 'audio_muted';
  static const String themeDark = 'theme_dark';
}
```

Leave the rest of `storage_service.dart` (the `StorageService` class itself — `getBool`/`setBool`/`flush`/`maybe`/`to`) untouched.

- [ ] **Step 4: Trim `lib/core/audio_manager.dart`**

Read the file first. Delete the per-level/per-combo BGM track-switching methods and the SFX-by-name table driven from `asset/audio/notes/`; keep `init()`, `startBgm()`, `pauseBgm()`, `resumeBgm()`, and add/keep a `toggleMute()` that flips `StorageKeys.audioMuted` — those are the only methods `main.dart` and the new settings screen call.

- [ ] **Step 5: Delete the now-unused core files and their tests**

```bash
git rm lib/core/home_widget_sync.dart lib/core/utils/comeback_bonus.dart \
       lib/core/utils/weekend_event.dart lib/core/utils/friend_code.dart \
       test/core/app_translations_test.dart test/core/i18n_debt_test.dart \
       test/core/round9_i18n_test.dart test/core/home_widget_sync_test.dart \
       test/core/reminder_service_test.dart \
       test/core/utils/comeback_bonus_test.dart \
       test/core/utils/weekend_event_test.dart \
       test/core/utils/friend_code_test.dart
```

- [ ] **Step 6: Fix `test/core/storage_service_test.dart`**

Read the file, remove every assertion referencing a deleted `StorageKeys` constant (`coins`, `highScore`, `star`, `bombCount`, etc.), keep the ones covering `localeCode`/`audioMuted`/`themeDark` plus the generic `getBool`/`setBool`/`flush` round-trip tests.

- [ ] **Step 7: Run the still-compiling core test slice**

Run: `flutter test test/core --exclude-tags slow`
Expected: PASS (this slice doesn't depend on the still-broken `main.dart`/screens fixed in Task 4).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: reduce core services to base-project scope"
```

---

### Task 4: Rewrite the app entry point and add minimal home/settings screens

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/presentation/screens/home_screen.dart`
- Create: `lib/presentation/screens/settings_screen.dart`
- Create: `integration_test/app_boot_test.dart` (the one runnable check for this task's non-trivial boot-sequence change)
- Delete: `integration_test/backup_restore_test.dart`, `core_economy_test.dart`, `lifecycle_test.dart`, `meta_progression_test.dart`, `new_modes_test.dart`, `reset_progress_test.dart`, `save_resilience_test.dart`, `undo_test.dart` (all exercise deleted systems)

**Interfaces:**
- Consumes: `StorageService(prefs)`, `StorageKeys.{localeCode,audioMuted,themeDark}`, `LocaleService(store)`, `AudioManager` (`init/startBgm/pauseBgm/resumeBgm/toggleMute`), `ReminderService` (`scheduleNext`), `AppTranslations` (`supported`, `fallback`) — all from Task 3.
- Produces: `app({bool withAudio = true})`, `restartApp()` (same signatures as today, so `E2E_TEST` integration tests can still call them), `HomeScreen` (no constructor args), `SettingsScreen` (no constructor args).

- [ ] **Step 1: Rewrite `lib/main.dart`**

Read the current file first (already read above — the only changes are: drop `GameController` entirely, rename the app class/title, drop the `NeonTheme.dark` line only if `storage_service`'s trimmed keys still include `themeDark` — they do, so keep it):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/app_info.dart';
import 'core/app_translations.dart';
import 'core/audio_manager.dart';
import 'core/debug_log.dart';
import 'core/locale_service.dart';
import 'core/neon_theme.dart';
import 'core/reminder_service.dart';
import 'core/runtime_flags.dart';
import 'core/storage_service.dart';
import 'presentation/screens/home_screen.dart';

void main() => app();

Future<void> app({bool withAudio = true}) async {
  dlog('app: ensureInitialized');
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  WakelockPlus.enable();

  await loadAppVersion();

  final store = Get.put(StorageService(await _loadPrefs()), permanent: true);
  NeonTheme.dark = store.getBool(StorageKeys.themeDark);
  final locale = Get.put(LocaleService(store), permanent: true);
  Get.put(ReminderService(), permanent: true);
  Get.updateLocale(locale.current.value);

  if (withAudio) {
    Get.put(AudioManager(), permanent: true);
  }

  runApp(RoyBaseGameApp(initialLocale: locale.current.value));

  if (withAudio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioManager.maybe?.init().then((_) => AudioManager.maybe?.startBgm());
    });
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ReminderService.maybe?.scheduleNext();
  });
}

Future<void> restartApp() async {
  Get.deleteAll(force: true);
  await app(withAudio: !isE2eTest);
  Get.offAll(() => const HomeScreen());
}

Future<SharedPreferences?> _loadPrefs() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (e) {
    dlog('roy93~ SharedPreferences init failed, dùng in-memory fallback: $e');
    return null;
  }
}

bool _appVersionLoaded = false;

Future<void> loadAppVersion() async {
  if (_appVersionLoaded) return;
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) kAppVersion = info.version;
    if (info.buildNumber.isNotEmpty) kAppBuildNumber = info.buildNumber;
    if (info.packageName.isNotEmpty) kPackageName = info.packageName;
    _appVersionLoaded = true;
  } catch (_) {
    // keep fallback in app_info.dart, retry on next app() call
  }
}

class RoyBaseGameApp extends StatefulWidget {
  final Locale initialLocale;

  const RoyBaseGameApp({super.key, required this.initialLocale});

  @override
  State<RoyBaseGameApp> createState() => _RoyBaseGameAppState();
}

class _RoyBaseGameAppState extends State<RoyBaseGameApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = AudioManager.maybe;
    if (state == AppLifecycleState.resumed) {
      audio?.resumeBgm();
    } else {
      audio?.pauseBgm();
      StorageService.maybe?.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Roy Project Base Game',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
      translations: AppTranslations(),
      locale: widget.initialLocale,
      fallbackLocale: AppTranslations.fallback,
      supportedLocales: AppTranslations.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: NeonTheme.fontFamily,
        scaffoldBackgroundColor: NeonTheme.bgMid,
        colorScheme: ColorScheme.light(
          primary: NeonTheme.purple,
          secondary: NeonTheme.magenta,
          surface: NeonTheme.card,
          onSurface: NeonTheme.ink,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 2: Create `lib/presentation/screens/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/stroke_text.dart';
import 'settings_screen.dart';

/// Placeholder landing screen — replace with the new game's title screen.
/// Kept intentionally tiny: it only proves the boot sequence (Task 4) and
/// the kept widget kit (neon_bg/neon_button/stroke_text) still render.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StrokeText('Roy Project Base Game', fontSize: 28),
              const SizedBox(height: 24),
              NeonButton(
                label: 'settings'.tr,
                onTap: () => Get.to(() => const SettingsScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create `lib/presentation/screens/settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
import '../../core/storage_service.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Minimal settings screen — locale + audio mute. Exercises the 3 kept
/// StorageKeys end to end; extend per-project rather than growing this file.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StorageService.to;
    final locale = Get.find<LocaleService>();
    return Scaffold(
      appBar: NeonAppBar(title: 'settings'.tr),
      body: NeonBg(
        child: ListView(
          children: [
            ListTile(
              title: Text('language'.tr),
              trailing: DropdownButton<Locale>(
                value: locale.current.value,
                items: locale.supported
                    .map((l) => DropdownMenuItem(value: l, child: Text(l.languageCode)))
                    .toList(),
                onChanged: (l) {
                  if (l != null) locale.update(l);
                },
              ),
            ),
            SwitchListTile(
              title: Text('sound'.tr),
              value: !store.getBool(StorageKeys.audioMuted),
              onChanged: (on) {
                store.setBool(StorageKeys.audioMuted, !on);
                AudioManager.maybe?.toggleMute();
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

Read `lib/core/locale_service.dart` before this step to confirm the exact member names (`current`, `supported`, `update(...)` are assumed above — adjust to match if the real API differs).

- [ ] **Step 4: Delete the integration tests for deleted systems**

```bash
git rm integration_test/backup_restore_test.dart integration_test/core_economy_test.dart \
       integration_test/lifecycle_test.dart integration_test/meta_progression_test.dart \
       integration_test/new_modes_test.dart integration_test/reset_progress_test.dart \
       integration_test/save_resilience_test.dart integration_test/undo_test.dart
```

- [ ] **Step 5: Create `integration_test/app_boot_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_base_game/main.dart' as app;
import 'package:roy_base_game/presentation/screens/home_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to HomeScreen', (tester) async {
    await app.app(withAudio: false);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
```

Note: this uses the post-rename package name `roy_base_game` from Task 6. If Task 6 hasn't landed yet when this step runs, use whatever `name:` is currently in `pubspec.yaml` and revisit the import in Task 6's verification step.

- [ ] **Step 6: Run analyze + the full non-slow suite**

Run: `flutter analyze`
Expected: 0 issues.

Run: `flutter test --exclude-tags slow`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: rewrite app entry point with minimal home/settings screens"
```

---

### Task 5: Trim assets and `pubspec.yaml` dependencies

**Files:**
- Delete: `asset/audio/bkg1.ogg`, `asset/audio/bkg2.ogg`, `asset/audio/notes/` (whole dir — per-tile SFX table, unused after Task 3's `audio_manager.dart` trim)
- Modify: `pubspec.yaml`

**Interfaces:** None — asset/dependency pruning only, no code changes.

- [ ] **Step 1: Delete unused audio assets**

```bash
git rm asset/audio/bkg1.ogg asset/audio/bkg2.ogg
git rm -r asset/audio/notes
```

- [ ] **Step 2: Remove dependencies with no remaining consumer**

Read `pubspec.yaml` first, then remove these 5 lines from `dependencies:` (each confirmed single-consumer, and that consumer was deleted in Tasks 1–3):
- `cryptography: ^2.9.0` (only `lib/logic/backup_code.dart`, deleted Task 1)
- `qr_flutter: ^4.1.0` (only `lib/presentation/controllers/game_screen_controller.dart`, deleted Task 2)
- `in_app_review: ^2.0.12` (only the deleted `home_screen.dart`/`game_controller.dart`)
- `home_widget: ^0.9.2+1` (only `lib/core/home_widget_sync.dart`, deleted Task 3)
- `url_launcher: ^6.3.2` (only the deleted `home_screen.dart`)

Keep every other dependency (`flutter`, `flutter_localizations`, `intl`, `get`, `flame`, `shared_preferences`, `flame_audio`, `wakelock_plus`, `package_info_plus`, `share_plus`, `flutter_local_notifications`, `timezone`) — each still has a live consumer in the kept `lib/core/`.

- [ ] **Step 3: Fetch and verify**

Run: `flutter pub get`
Expected: resolves clean.

Run: `flutter analyze`
Expected: 0 issues (confirms no code silently depended on a removed package).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: prune unused audio assets and dependencies"
```

---

### Task 6: Rename the project (Dart package, Android, iOS, display name)

**Files:**
- Modify: `pubspec.yaml` (`name:`, `description:`, `version:`)
- Modify every file under `lib/`, `test/`, `integration_test/` importing `package:pop_star_blast/...`
- Modify: `android/app/build.gradle.kts` (`namespace`, `applicationId`)
- Modify: `android/app/src/main/AndroidManifest.xml` (`android:label`)
- Move + modify: `android/app/src/main/kotlin/com/galaxyjoy/pop_star_blast/MainActivity.kt` → `android/app/src/main/kotlin/com/galaxyjoy/roybasegame/MainActivity.kt` (update its `package` declaration)
- Delete: `android/app/src/main/kotlin/com/galaxyjoy/pop_star_blast/StreakWidgetProvider.kt` (native home-widget provider for the deleted `home_widget_sync.dart`) and any AppWidget-related `<receiver>` entry in `AndroidManifest.xml` plus its `res/xml`/`res/layout` widget resources
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (3 `PRODUCT_BUNDLE_IDENTIFIER = com.galaxyjoy.popStarBlast;` → `com.galaxyjoy.royBaseGame;`, 3 `...popStarBlast.RunnerTests;` → `...royBaseGame.RunnerTests;`)
- Modify: `ios/Runner/Info.plist` (`CFBundleDisplayName`, `CFBundleName`)

**Interfaces:** None — this is a mechanical rename; every symbol name stays the same, only the package/bundle identifiers and app title change.

- [ ] **Step 1: Rename the Dart package and sweep imports**

```bash
sed -i '' 's/^name: pop_star_blast$/name: roy_base_game/' pubspec.yaml
sed -i '' 's/^description:.*/description: "Roy Project Base Game — a lean Flutter+GetX+Flame starting point."/' pubspec.yaml
sed -i '' 's/^version:.*/version: 0.1.0+1/' pubspec.yaml

grep -rl "package:pop_star_blast" lib test integration_test | \
  xargs sed -i '' 's/package:pop_star_blast/package:roy_base_game/g'
```

- [ ] **Step 2: Rename the Android package**

```bash
sed -i '' 's/com\.galaxyjoy\.pop_star_blast/com.galaxyjoy.roybasegame/' android/app/build.gradle.kts
sed -i '' 's/android:label="Pop Star Blast"/android:label="Roy Project Base Game"/' android/app/src/main/AndroidManifest.xml

mkdir -p android/app/src/main/kotlin/com/galaxyjoy/roybasegame
git mv android/app/src/main/kotlin/com/galaxyjoy/pop_star_blast/MainActivity.kt \
        android/app/src/main/kotlin/com/galaxyjoy/roybasegame/MainActivity.kt
sed -i '' 's/package com\.galaxyjoy\.pop_star_blast/package com.galaxyjoy.roybasegame/' \
  android/app/src/main/kotlin/com/galaxyjoy/roybasegame/MainActivity.kt

git rm android/app/src/main/kotlin/com/galaxyjoy/pop_star_blast/StreakWidgetProvider.kt
rmdir android/app/src/main/kotlin/com/galaxyjoy/pop_star_blast 2>/dev/null || true
```

Then read `android/app/src/main/AndroidManifest.xml` and remove the `<receiver android:name=".StreakWidgetProvider" ...>` block (and any `<meta-data>` under it pointing at a widget-info XML), and check `android/app/src/main/res/xml/` + `android/app/src/main/res/layout/` for a widget-info/widget-layout file referenced by that receiver — delete it if present:

Run: `grep -n "StreakWidgetProvider\|appwidget" -r android/app/src/main`

Expected after the manual edit: no matches.

- [ ] **Step 3: Rename the iOS bundle id and display name**

```bash
sed -i '' 's/com\.galaxyjoy\.popStarBlast/com.galaxyjoy.royBaseGame/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/<string>Pop Star Blast<\/string>/<string>Roy Project Base Game<\/string>/' ios/Runner/Info.plist
sed -i '' 's/<string>pop_star_blast<\/string>/<string>roy_base_game<\/string>/' ios/Runner/Info.plist
```

- [ ] **Step 4: Fix `integration_test/app_boot_test.dart`'s import if Task 4 wrote it against the old name**

Run: `grep -n "package:pop_star_blast" integration_test/app_boot_test.dart`
Expected: no match (Step 1's sweep already caught it since it lives under `integration_test/`).

- [ ] **Step 5: Sweep for anything left over**

Run: `grep -rn "pop_star_blast\|popStarBlast\|Pop Star Blast" . --exclude-dir=.git --exclude-dir=build --exclude-dir=docs`

Expected: no matches (`docs/` is excluded because this plan file itself narrates the old name — that's history, not code).

- [ ] **Step 6: Verify**

Run: `flutter pub get && flutter analyze`
Expected: resolves clean, 0 issues.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: rename project to Roy Project Base Game"
```

---

### Task 7: Delete Pop Star Blast docs, rewrite README.md and CLAUDE.md

**Files:**
- Delete: `doc/` (whole directory — `doc/RELEASE_CHECKLIST.md`, `doc/feat.md`, `doc/README.md`, `doc/guide.md`, `doc/task/` with its 156 task spec files)
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Delete the old docs**

```bash
git rm -r doc
```

- [ ] **Step 2: Rewrite `README.md`**

Read the current file first, then replace its content with something in this shape (adjust wording, keep it short):

```markdown
# Roy Project Base Game

A lean Flutter + GetX + Flame starting point. Stripped from a full match-3
game (Pop Star Blast, see `origin/main` history before this rename) down to
just the reusable core: storage, i18n, audio, haptics, local reminders,
theme tokens, and a small neon-styled widget kit.

## Commands

flutter analyze
flutter test --exclude-tags slow
flutter run -d <device-id>

## What's here

- `lib/core/` — storage (`StorageService`/`StorageKeys`), i18n
  (`AppTranslations`, 2 seed locales), `AudioManager`, `LocaleService`,
  `ReminderService`, `NeonTheme` design tokens, `Haptics`, `ShareHelper`.
- `lib/presentation/widgets/` — a small neon-styled widget kit
  (`NeonButton`, `NeonDialog`, `NeonAppBar`, `NeonBg`, `CoinChip`,
  `ConfettiOverlay`, ambient background layers).
- `lib/presentation/screens/` — `HomeScreen` + `SettingsScreen`, both
  placeholders — replace with your game's actual screens.
- `lib/logic/`, `lib/data/`, `lib/game/` — empty on purpose. Add your
  game's pure-Dart rules under `lib/logic/`, static content under
  `lib/data/`, and your Flame engine under `lib/game/`.

## Starting a new game from this base

1. Rename the package again if this clone needs its own identity (see
   `docs/superpowers/plans/2026-09-05-strip-to-base-game.md` Task 6 for the
   exact sed commands — same steps, different target name).
2. Fill `lib/logic/` + `lib/data/` + `lib/game/` with your game's rules.
3. Replace `HomeScreen`/`SettingsScreen` with real screens; wire a
   `GameController` the same way the original Pop Star Blast one did
   (single file, reactive `Rx` state, see git history before this rename
   for a worked example).
```

- [ ] **Step 3: Rewrite `CLAUDE.md`**

Read the current file first, then replace it with a version scoped to what actually exists post-strip: project one-liner (Flutter+GetX+Flame base, no game yet), the `flutter analyze`/`flutter test --exclude-tags slow` commands, the kept 4-layer architecture description (`lib/core` contents from Task 3's final state, the widget kit from Task 2, the empty `lib/logic`/`lib/data`/`lib/game`), the `StorageKeys` convention (must still route through `StorageKeys`, no string literals), the dialog-overlay convention (`NeonDialog.show`/`.overlay` — `Get.dialog` is a no-op over `GameWidget`, still true the moment a new game adds a `GameWidget`), and the i18n convention (seed 2 locales, add more the same way). Drop every section describing deleted systems (`GameMode`, meta-progression, side modes, negative-tile-ID bands, etc.) — none of it exists anymore.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: rewrite README and CLAUDE.md for the base project"
```

---

### Task 8: Final verification and push

**Files:** None — verification only.

- [ ] **Step 1: Full static + test verification**

Run: `flutter analyze`
Expected: 0 issues.

Run: `flutter test --exclude-tags slow`
Expected: PASS, 0 failures.

- [ ] **Step 2: Build verification**

Run: `flutter build apk --debug`
Expected: builds successfully (confirms the Android rename in Task 6 didn't break Gradle).

- [ ] **Step 3: Integration smoke test (if a device/emulator is available)**

Run: `flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true`
Expected: PASS.

- [ ] **Step 4: Push**

```bash
git push origin main
```

---

## Self-Review Notes

- **Spec coverage:** all 3 user decisions (strip to core-only, full rename, safety-net-already-done) are implemented — Task 1–5/7 = strip, Task 6 = full rename, Task 8 = push (the safety net itself already happened before this plan file was written, noted in the Spec section rather than repeated as a task).
- **Placeholder scan:** no TBD/"add error handling"/"similar to Task N" left — `home_screen.dart`/`settings_screen.dart`/`app_translations.dart`/`reminder_service.dart` are given in full; `StorageKeys` new body is given in full; every `git rm`/`sed` step names exact paths.
- **Type/name consistency:** `ReminderService.scheduleNext()`/`.maybe`, `AudioManager.init/startBgm/pauseBgm/resumeBgm/toggleMute`, `StorageKeys.{localeCode,audioMuted,themeDark}`, `HomeScreen`/`SettingsScreen` (no constructor args), `RoyBaseGameApp` — used identically across Tasks 3, 4, and 8's smoke test.
- One judgment call flagged inline rather than hidden: Step 3 of Task 4 assumes `LocaleService`'s member names (`current`, `supported`, `update`) — read the real file before writing that screen, the plan says so explicitly because this is the one place a guess could be wrong.
