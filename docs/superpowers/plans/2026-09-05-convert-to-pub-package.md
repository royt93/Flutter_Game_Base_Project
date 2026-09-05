# Convert to pub.dev Package (`roy_casual_kit`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert this repo, in place (same git remote, no new repo), from a Flutter *app* ("Roy Project Base Game", package `roy_base_game`) into a proper pub.dev *package* named `roy_casual_kit` — a reusable core-services + casual-game-widget library — with a runnable `example/` app (the current widget showcase), MIT license, English public API docs, and package-shaped CI.

**Architecture:** Everything under `lib/core/` and `lib/presentation/widgets/common/` (+ its barrel) IS the package — it stays at the repo root's `lib/`. Everything app-specific (`lib/main.dart`, the 3 screens, `android/`, `ios/`, `asset/icon/*`) moves under a new `example/` directory that depends on the root package via a `path:` pubspec dependency — the standard Flutter package layout. No new abstractions, no redesign of the 21 widgets or core services themselves — this is a repo-shape change plus a rename plus a doc-language pass.

**Tech Stack:** Same as before (Flutter, GetX, Flame) — no new runtime dependencies. Package-authoring tooling: standard `pubspec.yaml` package fields, `LICENSE`, `CHANGELOG.md`, `flutter pub publish --dry-run` for pre-publish validation.

**Spec:** Decided inline in conversation (no separate spec doc). Summary of user decisions this plan implements:
1. Convert THIS repo into the package (not a separate new repo) — single git remote (`github.com/royt93/Flutter_Game_Base_Project`) stays as-is; renaming the GitHub repo itself is the user's call, out of scope here.
2. Package name: `roy_casual_kit`. License: MIT.
3. One package (not split into theme/widgets/core sub-packages).
4. The existing `widget_showcase_screen.dart` becomes the package's official `example/` app (not a separate minimal example).
5. Public dartdoc comments translate Vietnamese → English (internal reasoning comments, e.g. `roy93~`-prefixed ones, stay as-is — this is a public-API-doc-only pass).
6. `.github/workflows/nightly.yml` (device-gate CI) and `tool/release_device_gate.sh` (the script it calls) are deleted outright — a package doesn't need nightly device-farm gating.
7. Theming stays static (`NeonTheme` keeps its `static const`/getter shape) — a `configure()` override hook is a possible *future* addition, NOT part of this plan (out of scope, mentioned here only so a future task doesn't reintroduce the question).

## Global Constraints

- `flutter analyze` must show 0 issues (root package AND `example/`) at the end of every task from Task 2 onward (Task 1 necessarily leaves things broken mid-move — same carve-out pattern as the earlier strip plan: Task 1's own listed verification is its gate, not the blanket line).
- `flutter test --exclude-tags slow` must fully pass (root package AND, once it exists, `example/`) from Task 2 onward.
- Every file move uses `git mv` (preserves history), every deletion uses `git rm`.
- No new pubspec dependencies beyond what's already in the repo — this is a re-shaping, not a feature addition.
- Vietnamese internal/reasoning comments (non-doc, or doc comments on private members) are NOT in scope for the translation task (Task 4) — only public API dartdoc (`///` on public classes/members) gets translated.

---

### Task 1: Extract the app shell into `example/`

**Files:**
- Move (via `git mv`): `lib/main.dart` → `example/lib/main.dart`
- Move: `lib/presentation/screens/home_screen.dart` → `example/lib/screens/home_screen.dart`
- Move: `lib/presentation/screens/settings_screen.dart` → `example/lib/screens/settings_screen.dart`
- Move: `lib/presentation/screens/widget_showcase_screen.dart` → `example/lib/screens/widget_showcase_screen.dart`
- Move: `android/` (whole directory) → `example/android/`
- Move: `ios/` (whole directory) → `example/ios/`
- Move: `asset/icon/` (whole directory: `ic_launcher.png`, `ios_background.png`, `android12_splash.xml`) → `example/asset/icon/`
- Move: `test/widget/settings_screen_test.dart` → `example/test/settings_screen_test.dart`
- Move: `test/widget/widget_showcase_screen_test.dart` → `example/test/widget_showcase_screen_test.dart`
- Create: `example/pubspec.yaml`
- Create: `example/analysis_options.yaml` (copy the root's — same `flutter_lints` include)
- Modify: the 3 moved screen files + `example/lib/main.dart` (import-path fixes — see below)
- Modify: root `pubspec.yaml` — remove the `flutter.assets: - asset/icon/` reference IF one exists (check; the current pubspec only lists `asset/audio/`, so this may be a no-op) and remove the `icons_launcher:`/`flutter_native_splash:` top-level config blocks (they reference `asset/icon/...` paths that just moved) — Task 2 rewrites the rest of root `pubspec.yaml`, so only touch what's needed to keep `flutter analyze` from choking on a missing asset path here.

**Interfaces:**
- Produces: `example/pubspec.yaml` with a `roy_base_game: {path: ../}` dependency (still the OLD package name — Task 3 renames it to `roy_casual_kit` everywhere including here) plus `wakelock_plus: ^1.4.0`, `package_info_plus: ^9.0.1`, `flutter_localizations: {sdk: flutter}`, `shared_preferences: ^2.5.5` (needed as a *direct* dependency in `example/` too, per Dart's `depend_on_referenced_packages` lint, even though `main.dart` only reads it indirectly via `StorageService`... check by reading `example/lib/main.dart`'s actual imports once moved — if it imports `shared_preferences` directly for `SharedPreferences.getInstance()`, the direct dependency is required; if it only calls through `StorageService`, it may not be — verify via `flutter analyze` in Step 6, don't guess).
- Consumes: nothing new — every moved file's *content* is unchanged except import paths.

- [ ] **Step 1: Move the files**

```bash
mkdir -p example/lib/screens example/test
git mv lib/main.dart example/lib/main.dart
git mv lib/presentation/screens/home_screen.dart example/lib/screens/home_screen.dart
git mv lib/presentation/screens/settings_screen.dart example/lib/screens/settings_screen.dart
git mv lib/presentation/screens/widget_showcase_screen.dart example/lib/screens/widget_showcase_screen.dart
git mv android example/android
git mv ios example/ios
mkdir -p example/asset
git mv asset/icon example/asset/icon
git mv test/widget/settings_screen_test.dart example/test/settings_screen_test.dart
git mv test/widget/widget_showcase_screen_test.dart example/test/widget_showcase_screen_test.dart
rmdir lib/presentation/screens 2>/dev/null || true
```

- [ ] **Step 2: Fix the moved screens' + main.dart's imports**

Read each of the 4 moved files (`example/lib/main.dart`, `example/lib/screens/home_screen.dart`, `example/lib/screens/settings_screen.dart`, `example/lib/screens/widget_showcase_screen.dart`). Every relative import that used to reach into `lib/core/` or `lib/presentation/widgets/` (e.g. `import '../../core/app_translations.dart';`, `import '../widgets/neon_bg.dart';`, `import '../widgets/common/bottom_sheet_panel.dart';`) must become a `package:roy_base_game/...` import instead (e.g. `import 'package:roy_base_game/core/app_translations.dart';`, `import 'package:roy_base_game/presentation/widgets/neon_bg.dart';`) — because these files now live in a *different* package (`example`) that depends on the root package (`roy_base_game`, soon `roy_casual_kit`) rather than living inside it. Imports that reference each other among the 3 screens/main.dart (all now co-located in `example/lib/`) can stay relative (e.g. `home_screen.dart` importing `settings_screen.dart` via `'settings_screen.dart'` or `'screens/settings_screen.dart'` depending on final relative position — check by reading, both moved into `example/lib/screens/` so a same-directory relative import applies).

- [ ] **Step 3: Create `example/pubspec.yaml`**

```yaml
name: roy_casual_kit_example
description: "Example app + widget showcase for the roy_base_game package."
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.9.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  roy_base_game:
    path: ../
  wakelock_plus: ^1.4.0
  package_info_plus: ^9.0.1
  shared_preferences: ^2.5.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  integration_test:
    sdk: flutter
  icons_launcher: ^3.0.3
  flutter_native_splash: ^2.4.7

flutter:
  uses-material-design: true

icons_launcher:
  image_path: "asset/icon/ic_launcher.png"
  platforms:
    android:
      enable: true
      adaptive_background_color: "#7ED8FF"
      adaptive_foreground_image: "asset/icon/ic_launcher.png"
    ios:
      enable: true

flutter_native_splash:
  color: "#7ED8FF"
  image_android: asset/icon/ic_launcher.png
  background_image_ios: asset/icon/ios_background.png
  fullscreen: true
  android_gravity: center
  android_12:
    color: "#7ED8FF"
    image: asset/icon/ic_launcher.png
```

(This is the exact content — verify the `shared_preferences` line is actually needed once Step 2/6 confirm the real import; if `flutter analyze` in `example/` doesn't flag `depend_on_referenced_packages` for it, you may drop it, but leaving it in is harmless and simpler — don't spend time removing it if unsure.)

- [ ] **Step 4: Create `example/analysis_options.yaml`**

Read the root `analysis_options.yaml` and copy it verbatim into `example/analysis_options.yaml`.

- [ ] **Step 5: Fix root `pubspec.yaml`'s dangling asset references**

Read the root `pubspec.yaml`. Remove the `icons_launcher:` and `flutter_native_splash:` top-level blocks entirely (their `asset/icon/...` paths no longer exist at the root — they moved to `example/`). Do NOT do the rest of Task 2's pubspec rewrite here (dependency trimming, license field, etc.) — just remove these two now-broken blocks so `flutter analyze`/`flutter pub get` don't choke on a missing path.

- [ ] **Step 6: Verify**

Run `flutter pub get` at the root — must resolve clean.
Run `cd example && flutter pub get` — must resolve clean (this is the first time this directory exists as its own package; expect it to need a real `flutter pub get` run, not just an analyze).
Run `flutter analyze` at the root — must be 0 issues.
Run `cd example && flutter analyze` — must be 0 issues (fix any leftover relative-vs-package import mistake from Step 2 here).
Run `flutter test --exclude-tags slow` at the root — must fully pass (the 2 screen tests are gone from here now, moved to `example/test/` — expect a lower test count than before, that's correct).
Run `cd example && flutter test` — must fully pass (the 2 moved tests now live here).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: extract app shell (main.dart, screens, android/ios, launcher assets) into example/"
```

---

### Task 2: Rewrite root `pubspec.yaml` as a package pubspec + add LICENSE/CHANGELOG

**Files:**
- Modify: root `pubspec.yaml`
- Create: `LICENSE` (MIT)
- Create: `CHANGELOG.md`

**Interfaces:**
- Produces: a `pubspec.yaml` with `publish_to:` removed, `homepage`/`repository`/`topics`/`issue_tracker` fields pointing at `https://github.com/royt93/Flutter_Game_Base_Project`, and a `dependencies:` list trimmed to only what `lib/core`/`lib/presentation/widgets` actually import.

- [ ] **Step 1: Confirm the dependency split by grep, don't trust the plan's list blindly**

Run: `grep -rl "package:wakelock_plus\|package:package_info_plus\|package:flutter_localizations" lib/`
Expected: no matches (these 3 are only used by what's now `example/lib/main.dart`). If any DO match something still in root `lib/`, stop and report — don't remove a dependency something in `lib/` still needs.

- [ ] **Step 2: Rewrite root `pubspec.yaml`**

Read the current file first (Task 1 already removed the `icons_launcher`/`flutter_native_splash` blocks). Replace it with:

```yaml
name: roy_base_game
description: "A lean core-services + casual-game widget kit for Flutter (GetX + Flame): storage, i18n, audio, haptics, local reminders, theme tokens, and a 21-widget candy-styled UI kit."
version: 0.1.0
homepage: https://github.com/royt93/Flutter_Game_Base_Project
repository: https://github.com/royt93/Flutter_Game_Base_Project
issue_tracker: https://github.com/royt93/Flutter_Game_Base_Project/issues
topics:
  - widgets
  - game
  - ui
  - flame
  - casual-game

environment:
  sdk: ^3.9.0

dependencies:
  flutter:
    sdk: flutter
  intl: ^0.20.2
  get: ^4.7.3
  flame: ^1.35.1
  shared_preferences: ^2.5.5
  flame_audio: ^2.11.14
  share_plus: ^12.0.2
  flutter_local_notifications: ^20.1.0
  timezone: ^0.10.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true

  assets:
    - asset/audio/

  fonts:
    - family: Baloo2
      fonts:
        - asset: asset/fonts/Baloo2.ttf

  shaders:
    - shaders/neon_glow.frag
    - shaders/aurora_bg.frag
```

Note: `version` dropped its `+1` build-number suffix (build numbers are an app-versioning concept — Android/iOS `versionCode`/`CFBundleVersion` — meaningless for a pub.dev package version, which is pure semver). Note `integration_test` (dev dependency) is dropped from the root — the root package's own `test/` has no integration tests (those lived in what's now `example/`) — if Task 1's `flutter test` step still finds an `integration_test` import somewhere in root `test/`, keep it; check first, don't remove blindly.

- [ ] **Step 3: Create `LICENSE`**

Use the standard MIT license text, copyright line `Copyright (c) 2026 <the repo owner — use the GitHub org/user "royt93">`.

- [ ] **Step 4: Create `CHANGELOG.md`**

```markdown
## 0.1.0

- Initial release: core services (storage, i18n, audio, haptics, local reminders, theme tokens) and a 21-widget casual-game UI kit (buttons, overlays, progress/reward, layout & cards).
```

- [ ] **Step 5: Verify**

Run `flutter pub get` at the root — must resolve clean.
Run `flutter analyze` at the root — must be 0 issues.
Run `flutter test --exclude-tags slow` at the root — must fully pass.
Run `cd example && flutter pub get && flutter analyze` — must still be clean (the root package's public `name`/version didn't change in a way that breaks the path dependency, but re-verify since Task 1's `example/pubspec.yaml` pins `roy_base_game: {path: ../}` by name — confirm the name match still holds after this rewrite; it does, `name:` is unchanged here).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: rewrite pubspec.yaml as a package manifest, add LICENSE and CHANGELOG"
```

---

### Task 3: Rename the package `roy_base_game` → `roy_casual_kit`

**Files:**
- Modify: root `pubspec.yaml` (`name:`)
- Modify: every file under `lib/`, `test/` importing `package:roy_base_game/...`
- Modify: `example/pubspec.yaml` (`roy_base_game: {path: ../}` → `roy_casual_kit: {path: ../}`)
- Modify: every file under `example/lib/`, `example/test/` importing `package:roy_base_game/...`

**Interfaces:** None — mechanical rename, no symbol names change.

- [ ] **Step 1: Rename**

```bash
sed -i '' 's/^name: roy_base_game$/name: roy_casual_kit/' pubspec.yaml
grep -rl "package:roy_base_game" lib test | xargs sed -i '' 's/package:roy_base_game/package:roy_casual_kit/g'
sed -i '' 's/roy_base_game:/roy_casual_kit:/' example/pubspec.yaml
grep -rl "package:roy_base_game" example/lib example/test | xargs sed -i '' 's/package:roy_base_game/package:roy_casual_kit/g'
```

- [ ] **Step 2: Sweep for anything left over**

Run: `grep -rn "roy_base_game" . --exclude-dir=.git --exclude-dir=build --exclude-dir=docs`
Expected: no matches (`docs/` excluded — this plan file and the earlier strip plan narrate the old name as history).

- [ ] **Step 3: Verify**

Run `flutter pub get && flutter analyze` at the root — must be 0 issues.
Run `cd example && flutter pub get && flutter analyze` — must be 0 issues.
Run `flutter test --exclude-tags slow` at the root, and `cd example && flutter test` — both must fully pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: rename package to roy_casual_kit"
```

---

### Task 4a: Translate public dartdoc to English — `lib/core/`

**Files:** Modify (comment-only, no logic changes) every file in `lib/core/*.dart` and `lib/core/utils/*.dart` (14 files: `app_info.dart`, `app_translations.dart`, `audio_manager.dart`, `debug_log.dart`, `haptics.dart`, `locale_service.dart`, `neon_theme.dart`, `reminder_service.dart`, `runtime_flags.dart`, `share_helper.dart`, `storage_service.dart`, `utils/clamped_clock.dart`, `utils/format.dart`, `utils/label_fit.dart`).

**Interfaces:** None — comment text only.

- [ ] **Step 1: Translate**

For each file, translate every `///` doc comment on a **public** class/member from Vietnamese to English. Leave non-doc comments (`//`, especially any `roy93~`-prefixed internal-reasoning ones) in Vietnamese — those are implementation notes, not public API documentation, and out of scope. Leave doc comments on **private** (`_`-prefixed) members as-is too (optional to translate, not required). Preserve all `[SquareBracket]` doc-comment cross-references (dartdoc link syntax) exactly — only translate the prose around them.

- [ ] **Step 2: Verify**

Run `flutter analyze` at the root — must stay 0 issues (a doc-only change should never introduce an analyzer issue, but verify anyway — a broken dartdoc reference syntax can trigger a lint).
Run `flutter test --exclude-tags slow` at the root — must stay fully passing (comment-only changes shouldn't affect behavior, but this is the actual proof).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: translate lib/core public API dartdoc to English"
```

---

### Task 4b: Translate public dartdoc to English — `lib/presentation/widgets/common/`

**Files:** Modify (comment-only) every file in `lib/presentation/widgets/common/` (22 files: the barrel `common_widgets.dart` + 21 widget files).

**Interfaces:** None.

- [ ] **Step 1: Translate**

Same rule as Task 4a: public `///` doc comments → English, non-doc/internal comments stay Vietnamese, private-member docs optional.

- [ ] **Step 2: Verify**

Run `flutter analyze` at the root — 0 issues. Run `flutter test --exclude-tags slow` at the root — fully passing.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: translate common widget kit public API dartdoc to English"
```

---

### Task 5: Delete app-only CI, extend package CI for `example/`

**Files:**
- Delete: `.github/workflows/nightly.yml`
- Delete: `tool/release_device_gate.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:** None.

- [ ] **Step 1: Delete the app-only CI**

```bash
git rm .github/workflows/nightly.yml tool/release_device_gate.sh
rmdir tool 2>/dev/null || true
```

- [ ] **Step 2: Extend `ci.yml` to also check `example/`**

Read the current `ci.yml` first. After its existing `flutter pub get && flutter analyze && flutter test --exclude-tags slow` steps (root), add the same 3 commands run with `working-directory: example` (or `cd example &&` prefix, matching whatever style the file already uses for its steps).

- [ ] **Step 3: Verify**

There's no way to run GitHub Actions locally in this environment — instead, manually re-run the exact commands the updated workflow would run: `flutter pub get && flutter analyze && flutter test --exclude-tags slow` at the root, then the same 3 inside `example/`. All must pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "ci: drop app-only nightly device gate, extend ci.yml to check example/"
```

---

### Task 6: Rewrite README.md and CLAUDE.md for the package

**Files:**
- Modify: root `README.md`
- Modify: root `CLAUDE.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Rewrite `README.md`**

Read the current file first, then replace its content with package-usage framing: what the package is (core services + 21-widget casual-game UI kit), installation (`flutter pub add roy_casual_kit` once published, or a `path:`/`git:` dependency for local use pre-publish), a short usage example (e.g. import the barrel, drop a `CommonButton` in a widget tree), a link/pointer to `example/` ("run `cd example && flutter run` to see every widget live"), and a one-paragraph note on this repo's own history (stripped from a full match-3 game, "Pop Star Blast" — see git history — into a reusable base, then further reshaped into this package; the prior `docs/superpowers/plans/2026-09-05-strip-to-base-game.md` plan documents that first step).

- [ ] **Step 2: Rewrite `CLAUDE.md`**

Read the current file first, then replace it with guidance scoped to the new reality: this is a PACKAGE (`lib/` = the 11 core files + 21 common widgets, nothing else), `example/` is a separate Flutter app depending on it via `path:`, and any new reusable core service or widget goes in the package `lib/`, while anything that demonstrates/exercises usage (or is app-specific — a new demo screen, different navigation) goes in `example/lib/`. Keep the existing accurate sections (StorageKeys convention, Dialog pattern, i18n convention, NeonBg's permanent-Ticker testing gotcha) — update only what changed (drop any remaining "app" framing, update the file/directory list to reflect `example/`'s existence, update the `flutter test`/`flutter analyze` command examples to show both root and `example/` invocations).

- [ ] **Step 3: Verify**

No code changes in this task — just confirm `flutter analyze`/`flutter test --exclude-tags slow` are still green at the root (they should be untouched by a docs-only task, but this is the standing gate).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: rewrite README and CLAUDE.md for the package + example structure"
```

---

### Task 7: Final verification and push

**Files:** None — verification only.

- [ ] **Step 1: Full gate, both projects**

Run `flutter pub get && flutter analyze && flutter test --exclude-tags slow` at the root — must be clean.
Run the same 3 commands inside `example/` — must be clean.

- [ ] **Step 2: Pre-publish dry run**

Run `flutter pub publish --dry-run` at the root. This validates the package against real pub.dev publishing rules (valid `pubspec.yaml`, `LICENSE` present, no `publish_to: none` left over, package size, etc.) WITHOUT actually publishing. Fix anything it flags as an ERROR (warnings about missing example/README polish are fine to leave for a human judgment call — report them, don't necessarily fix every one). Do NOT run `flutter pub publish` (without `--dry-run`) — that would actually publish to pub.dev, which is irreversible and not authorized by this plan.

- [ ] **Step 3: Device smoke test (if a device/emulator is available)**

Run `cd example && flutter run -d <device-id>` and confirm the app boots to `HomeScreen` and the Widget Kit showcase opens without crashing (same manual check the user already did earlier this session on their physical device — re-confirm after the `example/` extraction, since the app's location/dependency shape changed).

- [ ] **Step 4: Push**

```bash
git push origin main
```

Only after explicit user confirmation (same push-confirmation pattern used throughout this session) — do not push without asking first.

---

## Self-Review Notes

- **Spec coverage:** all 7 numbered decisions in the Spec section map to a task: (1) same-repo conversion → Task 1; (2) name/license → Tasks 2-3; (3) single package → implicit (never split); (4) showcase-as-example → Task 1; (5) English dartdoc → Tasks 4a/4b; (6) delete nightly.yml → Task 5; (7) static theming stays → no task touches `NeonTheme`'s shape (confirmed out of scope).
- **Placeholder scan:** no TBD/"add error handling" placeholders — every task gives exact commands or exact file content (`example/pubspec.yaml`, root `pubspec.yaml`, `CHANGELOG.md` given verbatim).
- **Type/name consistency:** package name `roy_casual_kit` used identically from Task 3 onward; `example/pubspec.yaml`'s dependency name matches Task 3's rename.
- **Known risk flagged inline:** Task 1 Step 2 (import-path fixes in the 4 moved files) and Task 1 Step 3's `shared_preferences` direct-dependency question are both explicitly marked "verify by reading/analyzing, don't guess" — these are the two places a plan-time assumption could be wrong against the real file contents.
