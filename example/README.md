# roy_casual_kit example

This is a full, production-style Flutter app — not a trimmed-down "hello
world" demo. `lib/main.dart` wires up real usage of most modules the root
package README documents: bootstrap (`RoyCasualKit.initialize`), lifecycle
coordination, deep links, audio, local reminders, theming, and the
debug/QA overlay. Read it directly for the actual integration pattern
instead of a single isolated snippet — that's the fastest way to see how
the pieces fit together in a real app.


## Non-technical demo script

Use this 2-minute script when showing the app to someone who does not read code:

1. Run the example app.
2. From Home, open **Game Demo**.
3. Tap the circle 10 times.
4. Check these visible results:
   - `tap: 10/10`
   - `gems: 20`
   - star achievement icon
   - confetti burst
5. Press the phone Home button or background the app, then return.
6. Check that the pause panel appears while backgrounded and disappears after resume.

This single flow demonstrates gameplay events, reward economy, achievement unlock, confetti, haptics, repaint isolation, and memory trim lifecycle behavior.

## Proof tests

Focused D4 proof:

```bash
flutter test integration_test/d4_perf_memory_test.dart
```

Game demo widget proof:

```bash
flutter test test/game_demo_screen_test.dart
```

Release build proof:

```bash
flutter build apk --release
```

## Run it

```bash
cd example
flutter run
```

## Where to look

- `lib/main.dart` — app bootstrap: `RoyCasualKit.initialize(...)` module
  wiring, error handlers, deep-link routing, theme setup.
- `lib/screens/home_screen.dart` — navigation entrypoint.
- `lib/screens/widget_showcase_screen.dart` — every widget in
  `lib/presentation/widgets/common/`, one section per widget, with the
  exact constructor call used — the living reference for widget usage.
- `lib/screens/game_demo_screen.dart` — embedding the package's Flame
  `RoyGame` inside a normal Flutter widget tree, with `FlameTrackedOverlay`
  for HUD elements positioned in world space.
- `lib/screens/settings_screen.dart` — locale, audio mute, and theme
  (dark / color-blind-safe) toggles.

For what each core service (storage, economy, live-ops, analytics, …)
actually does, see the root package README.
