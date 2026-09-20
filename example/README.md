# roy_casual_kit example

This is a full, production-style Flutter app — not a trimmed-down "hello
world" demo. `lib/main.dart` wires up real usage of most modules the root
package README documents: bootstrap (`RoyCasualKit.initialize`), lifecycle
coordination, deep links, audio, local reminders, theming, and the
debug/QA overlay. Read it directly for the actual integration pattern
instead of a single isolated snippet — that's the fastest way to see how
the pieces fit together in a real app.

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
