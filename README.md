# roy_casual_kit

A Flutter package bundling the core services and casual-game widget kit
behind a Candy-Crush-style puzzle game: local storage, i18n, audio, haptics,
local reminders, and theme tokens, plus a 40-widget UI kit (buttons,
overlays, progress/reward, layout & cards, game-specific, and game-feel/juice)
built on GetX and styled with a bright candy palette.

## What's in the package

- `lib/core/` — `StorageService`/`StorageKeys` (SharedPreferences wrapper),
  `AppTranslations`/`LocaleService` (i18n), `AudioManager`, `Haptics`,
  `ReminderService` (local notifications), `NeonTheme` design tokens, plus
  `ShareHelper`, `AppInfo`, `RuntimeFlags`, `debug_log`, and small utils
  (clamped clock, number formatting, longest-word font-fit).
- `lib/presentation/widgets/` — the neon widget kit (`NeonButton`,
  `NeonDialog`, `NeonAppBar`, `NeonBg`, `NeonAuraLayer`, `AuroraBgLayer`,
  `NeonIcon`, `StrokeText`, `PressableScale`) plus
  `lib/presentation/widgets/common/`: 40 generic, game-agnostic widgets —
  buttons & interactive (`CommonButton`, `ToggleSwitch`, `SegmentedTabBar`,
  `IconBadgeButton`, `SoundToggleFab`), feedback & overlay
  (`LoadingOverlay`, `ToastBanner`, `TooltipBubble`, `BottomSheetPanel`,
  `ConfirmDialog`, `ConfettiOverlay`, `FloatingComboText`,
  `NetworkStatusBanner`, `ShimmerPlaceholder`, `SpotlightOverlay`), progress
  & reward (`ProgressBarStars`, `CircularProgressRing`, `StarRating`,
  `CurrencyCounter`, `RewardPopup`, `BadgeDot`, `StreakCounter`,
  `CountdownChip`, `PaginatedDotsIndicator`, `CoinFlyOverlay`,
  `DailyLoginCalendarWidget`, `EnergyBar`), layout & cards (`PanelCard`,
  `ListTileRow`, `SectionHeader`, `EmptyStatePlaceholder`, `AvatarFrame`,
  `RibbonBadge`, `ShopItemCard`, `VictoryCardTemplate`, `LeaderboardList`), game-specific
  (`LevelSelectGrid`), and game-feel/juice (`SquashStretch`, `ScreenShake`,
  `ComboHeatBackground`) — all exported from one barrel,
  `lib/presentation/widgets/common/common_widgets.dart`.

## Cheat-proof offline earnings

Idle/incremental games pay out rewards based on "how long was the player
away" — almost every other base kit computes that straight from
`DateTime.now()`, so winding the device clock back and forth farms free
rewards indefinitely. This kit's `OfflineProgressionService`
(`lib/core/offline_progression_service.dart`) is built on `ClampedClock`
(`lib/core/utils/clamped_clock.dart`) instead: a monotonic clock that never
goes backward, so a rewind attempt permanently burns the player's own future
time rather than resetting the calculation.

```dart
final offline = OfflineProgressionService(maxOfflineCap: const Duration(hours: 8));
Get.put(offline, permanent: true);

// e.g. on app resume, or whenever the player checks in:
final earned = await offline.claim(coinsPerSecond);
if (earned > 0) grantCoins(earned);
```

`maxOfflineCap` caps the payout (an 8h absence still only pays out 8 hours'
worth), and a fresh install never hands out a free payout on its very first
read — the baseline is seeded to "now", not epoch zero.

## Install

Not yet published to pub.dev. Once it is:

```bash
flutter pub add roy_casual_kit
```

For local testing before publishing, depend on it directly:

```yaml
dependencies:
  roy_casual_kit:
    path: ../roy_casual_kit # or: git: { url: ..., ref: main }
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonButton(
      label: 'Play',
      variant: CommonButtonVariant.primary,
      onTap: () => debugPrint('tapped'),
    );
  }
}
```

The same entrypoint exposes supported core services, Flame starter APIs and
the complete widget kit. Existing deep imports under `core/` and
`presentation/` remain available for advanced use, but new consumer code
should migrate to the entrypoint so the supported API surface is explicit.

For consumer tests, `RoyCasualKitTestFixture` provides deterministic in-memory
storage and `RoyCasualKitContractTestKit.verifyBootstrap` checks module
registration, error-free initialization and idempotent repeated setup without
network or vendor SDK dependencies.

## See it live

`example/` is a separate Flutter app (its own `pubspec.yaml`, `android/`,
`ios/`) that depends on this package via `path: ../` and exercises every
widget in `WidgetShowcaseScreen`:

```bash
cd example && flutter run
```

## Commands

```bash
# From the package root
flutter analyze
flutter test --exclude-tags slow

# From example/ — the demo app has its own test/analyze surface
cd example
flutter analyze
flutter test --exclude-tags slow
```

## History

This repo used to be a full match-3 puzzle game, "Pop Star Blast" (see git
history). It was first stripped down to a reusable app base — core services
plus a small widget kit, with `lib/logic/`, `lib/data/`, and `lib/game/`
emptied out — documented in
`docs/superpowers/plans/2026-09-05-strip-to-base-game.md`. It was then
reshaped again from an app into this pub.dev package: the reusable code
stayed at the repo root as `lib/`, and everything app-specific (entry point,
demo screens, `android/`, `ios/`) moved into a separate `example/` app that
depends on the package via a `path:` dependency — documented in
`docs/superpowers/plans/2026-09-05-convert-to-pub-package.md`.

## License

MIT — see `LICENSE`.
