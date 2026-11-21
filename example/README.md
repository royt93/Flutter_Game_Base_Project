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
2. From Home, tap **Game Demo** to open the mini-game hub.
3. In the hub, open **Classic Flame**.
4. Tap the circle 10 times.
5. Check these visible results:
   - `tap: 10/10`
   - `gems: 20`
   - star achievement icon
   - confetti burst
6. Press the phone Home button or background the app, then return.
7. Check that the pause panel appears while backgrounded and disappears after resume.

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

All paths below are relative to `example/`:

- `lib/main.dart` — app bootstrap: `RoyCasualKit.initialize(...)` module
  wiring, error handlers, deep-link routing, theme setup.
- `lib/screens/home_screen.dart` — navigation entrypoint for settings, the
  widget showcase, mini-game hub, rewards, shop, save/cloud, progression,
  season leaderboard, monetization, cookbook, and analytics ACK smoke demos.
- `lib/screens/mini_game_hub_screen.dart` — **Game Demo** destination from Home;
  choose **Classic Flame**, **Sprite Arena**, or **Match-3 Lite** here.
- `lib/screens/widget_showcase_screen.dart` — grouped widget and service-state
  demos; use it as the living reference for package widgets.
- `lib/screens/cookbook_screen.dart` — core service cookbook and integration
  examples.
- `lib/screens/game_demo_screen.dart`, `sprite_arena_demo_screen.dart`,
  `match3_lite_screen.dart` — individual game demos.
- Other focused demo screens include `settings_screen.dart`,
  `daily_reward_screen.dart`, `shop_screen.dart`, `save_cloud_screen.dart`,
  `level_progression_screen.dart`, `season_leaderboard_screen.dart`,
  `monetization_screen.dart`, and `analytics_ack_demo_screen.dart`.

For what each core service (storage, economy, live-ops, analytics, …)
actually does, see the root package README.
