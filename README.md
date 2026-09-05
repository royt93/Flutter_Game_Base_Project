# Roy Project Base Game

A lean Flutter + GetX + Flame starting point. Stripped from a full match-3
game (Pop Star Blast, see git history before this rename) down to just the
reusable core: storage, i18n, audio, haptics, local reminders, theme tokens,
and a small neon-styled widget kit.

## Commands

```bash
flutter analyze
flutter test --exclude-tags slow
flutter run -d <device-id>
```

## What's here

- `lib/core/` — storage (`StorageService`/`StorageKeys`), i18n
  (`AppTranslations`, 2 seed locales: en/vi), `AudioManager`, `LocaleService`,
  `ReminderService`, `NeonTheme` design tokens, `Haptics`, `ShareHelper`,
  `AppInfo`, `RuntimeFlags`, plus `lib/core/utils/` (clamped clock, number
  formatting, longest-word font-fit).
- `lib/presentation/widgets/` — a small neon-styled widget kit: `NeonButton`,
  `NeonDialog`, `NeonAppBar`, `NeonBg`, `NeonAuraLayer`, `AuroraBgLayer`,
  `NeonIcon`, `StrokeText`, `PressableScale`.
  - `ambient_particles`, `ambient_weather_layer`, `coin_chip`,
    `confetti_overlay`, and `pulse_glow` were removed as dead weight during
    the strip (they'd become orphaned by earlier deletions). If a project
    built on this base wants them back, they're recoverable from git history
    at commit `9262a03^` (the parent of "reduce core services to
    base-project scope" — i.e. right before they became orphaned).
- `lib/presentation/screens/` — `HomeScreen` + `SettingsScreen`, both
  placeholders — replace with your game's actual screens.
- `lib/logic/`, `lib/data/`, `lib/game/` — don't exist yet (deliberately, git
  doesn't track empty directories). Add your game's pure-Dart rules under
  `lib/logic/`, static content under `lib/data/`, and your Flame engine under
  `lib/game/`.

## Starting a new game from this base

1. Rename the package again if this clone needs its own identity (see
   `docs/superpowers/plans/2026-09-05-strip-to-base-game.md` Task 6 for the
   exact sed commands — same steps, different target name).
2. Create `lib/logic/` + `lib/data/` + `lib/game/` and fill them with your
   game's rules.
3. Replace `HomeScreen`/`SettingsScreen` with real screens; wire a
   `GameController` the same way the original Pop Star Blast one did
   (single file, reactive `Rx` state, see git history before this rename for
   a worked example).
