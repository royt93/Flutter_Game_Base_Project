# roy_casual_kit

A Flutter SDK for casual/idle games built on GetX + Flame: local storage,
i18n, audio, haptics, local reminders, theme tokens, an economy/progression
layer, live-ops and remote-content tooling, privacy-aware analytics, and a
candy-styled widget kit — one `RoyCasualKit.initialize(...)` call replaces
hand-rolling `Get.put` calls for every service a casual game typically needs
to build from scratch.

## What's in the package

`lib/core/` groups by what the service is for — grep `lib/roy_casual_kit.dart`
or `CLAUDE.md`'s Architecture section for the exhaustive, always-current list;
this is the shape, not a full inventory:

- **Bootstrap** — `RoyCasualKit.initialize(config: ...)` registers every
  requested core service idempotently and never throws; a failing module is
  reported in the result instead of crashing boot.
- **Storage & save data** — `StorageService` (SharedPreferences wrapper with
  a write-behind buffer for hot-path counters), `VersionedJsonStore` +
  `SaveMigrationRegistry` (schema-versioned saves with multi-hop migration),
  `SaveSlotManager`, `save_integrity.dart` (HMAC tamper detection),
  `DisasterRecoverySaveExport`, `CheckpointCoordinator`.
- **Economy & progression** — `EconomyWallet`, `RewardTransactionPipeline`,
  `PlayerProgressionService`, `InventoryService`, `EnergyService`,
  `OfflineProgressionService` (cheat-proof idle earnings, see below),
  `DailyLoginService`, `DailyQuestService`, `AchievementService`,
  `LocalScoreboardService`, `PurchaseLedgerService` + `PurchaseSeam`.
- **Live-ops & remote content** — `RemoteConfigService`, `RemoteContentPack`
  (signed, versioned, asset-fallback-then-fetch), the Remote Schema Compiler
  (`tool/remote_schema_compiler.dart`, compiles a declarative schema into a
  typed, self-contained Dart model), `RemoteKillSwitchController`,
  `SeasonEventService`, `ExperimentBucketingService`.
- **Privacy, analytics & diagnostics** — `ConsentStateService` +
  `ConsentGatedAnalyticsProvider`, `PrivacyAwareAnalyticsSampler`
  (consent-gated, deterministically-sampled, rate-limited),
  `SdkEventSchemaRegistry` (PII redaction before any event ships),
  `SdkHealthReport`, `DiagnosticsExportBundle`, `CrashReporter` seam.
- **Platform seams** (bring your own adapter) — `AnalyticsProvider`,
  `CrashReporter`, `CloudSaveProvider`, `PurchaseSeam`,
  `SecureStorageAdapter`, `RemoteConfigService`.
- **App/session infrastructure** — `AppVersionGate`, `AppSessionTracker`,
  `RoyLifecycleCoordinator`, `GameSessionController`, `GameTimeController`,
  `ConnectivityCoordinator`, `DeepLinkCommandRouter`,
  `OnboardingCoordinatorService`, `InAppReviewHelper`.
- **i18n, audio, haptics, theme** — `AppTranslations`/`LocaleService`,
  `AudioManager`, `Haptics` + `HapticChoreographer`, `NeonTheme` design
  tokens (light-candy default, neon-dark and color-blind-safe variants).
- **Dev/CI tooling** (`tool/`, headless `dart run`, no device needed) —
  accessibility audit, dependency SBOM/security gate, asset-license
  manifest check, API-compatibility gate, performance budget CI, pseudo-locale
  QA harness, consumer-app starter generator.

`lib/presentation/widgets/` — the neon widget kit (`NeonButton`,
`NeonDialog`, `NeonAppBar`, `NeonBg`, `NeonAuraLayer`, `AuroraBgLayer`,
`NeonIcon`, `StrokeText`, `PressableScale` — keyboard/gamepad-activatable,
not just touch) plus `lib/presentation/widgets/common/`: a large set of
generic, game-agnostic widgets spanning buttons/interactive, feedback/overlay,
progress/reward, layout/cards, game-specific, and game-feel/juice —
`example/lib/screens/widget_showcase_screen.dart` is the living usage
reference, and the whole set is exported from one barrel,
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

```bash
flutter pub add roy_casual_kit
```

For working against an unreleased local change, depend on it directly instead:

```yaml
dependencies:
  roy_casual_kit:
    path: ../roy_casual_kit # or: git: { url: ..., ref: main }
```

## Usage

Bootstrap the services a game needs once at startup, instead of hand-rolling
`Get.put` calls for each one:

```dart
await RoyCasualKit.initialize(
  config: RoyCasualKitConfig(
    modules: {
      RoyCasualKitModule.storage,
      RoyCasualKitModule.locale,
      RoyCasualKitModule.audio,
      RoyCasualKitModule.lifecycle,
    },
  ),
);
```

A module that fails to register is reported in the returned result instead
of crashing boot — see `RoyCasualKitResult`/`RoyCasualKitStatus`.

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

`example/` is a separate, full Flutter app (its own `pubspec.yaml`,
`android/`, `ios/`) — deliberately not a trimmed-down toy demo. Its
`lib/main.dart` wires up real usage of most modules covered above
(bootstrap, lifecycle, deep links, audio, reminders, theming); reading it
directly is the fastest way to see the actual integration pattern, not just
a single-widget snippet. See `example/README.md` for a tour of which file
covers what.

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
