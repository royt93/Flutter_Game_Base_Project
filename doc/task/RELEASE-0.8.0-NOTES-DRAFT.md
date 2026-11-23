# roy_casual_kit 0.8.0: release notes (DRAFT, not published)

Draft for the GitHub release body. Nothing here has been tagged or published.
The authoritative list is `CHANGELOG.md` (section 0.8.0).

## Breaking: rewarded ads removed

The kit no longer ships any advertising feature. Wire your own ad SDK in your
app.

Removed from the public API:

- `AdRewardSeam` (including `AdRewardSeam.maybe`, `isReady`, `showRewardedAd`)
- `RewardedAdResultCard`, `RewardedAdStatus`
- `PluginAdapterConformanceSuite.verifyAdRewardSeam`, `FakeAdRewardSeam`

Migration:

1. Delete `Get.put<AdRewardSeam>(...)` and any `verifyAdRewardSeam` call.
2. Replace `RewardedAdResultCard` with your own widget, or with the kit's
   `RewardPopup` / `VictoryCardTemplate` once your SDK reports a reward.
3. In-app purchases are unchanged: `PurchaseSeam`, `PurchaseLedgerService`
   and `PluginAdapterConformanceSuite.verifyPurchaseSeam` still work.

Because 0.x treats a minor bump as breaking, `^0.7.0` does not resolve to
0.8.0. Use `roy_casual_kit: ^0.8.0` once published.

## New: Match-3 engine in the package

`Match3Engine` moved from the example app into the package. It is pure Dart,
imports no Flutter code, and is deterministic with a seeded `Random`
(`SeededRandom` works).

- `Match3Config` sets board width, tile kinds, points per tile and the level
  table. `Match3Config.classic` (6x6, 5 tiles, 5 levels) is the default, so
  existing behavior is unchanged.
- `Match3Engine.useBooster(Match3Booster, index)`: row clear, column clear or
  3x3 bomb. Costs no move, then refills and cascades like a swap. Stock is
  yours to manage (for example with `InventoryService`).
- Behavior change: `Match3Engine.width`, `cellCount`, `tileKinds` and
  `pointsPerTile` are now instance getters. The hardcoded fallback board was
  replaced by retrying generation (throws `StateError` if a config cannot
  produce a playable board).

## New: GameSessionEngineBridge

Keeps a Flame `Game` paused while a `GameSessionController` is `paused` and
resumes it on `playing`, for every source including app background.

## Example app

A complete Match-3 loop in the example Home: boosters bought with coins,
level select with saved stars, victory and game-over cards with share, pause
menu, and a first-run tutorial. This is demo code, not package API.

## Platforms

Supported: Android and iOS. Web and desktop are not targets. A web build of
the package compiles after this release, but that is a side effect of two
integer fixes (`fnv1aHash`, `asIntOr`, plus a shared counter limit), not a
support claim; 48 host tests still fail on Chrome and are not planned.

## What is and is not verified

- Host tests, analyzer, API compatibility, accessibility, license, SBOM and
  performance-budget checks pass; see CI for the release commit.
- Device evidence is from a Google Pixel 7 Pro (Android 17), not the S24U:
  Match-3 flow (tutorial, booster, pause, restart) and the Flame pause bridge.
  Not covered on a device: the result-card share sheet, and a real app
  background (only simulated lifecycle events).
- No backend, store or ad network behavior is claimed. See
  `docs/qa/capability_evidence_matrix.md` and `docs/qa/device_matrix.md`.

## Before publishing (owner steps, not done here)

1. CI green on the release commit; run `dart run tool/release_readiness_check.dart`.
2. Change the consumer generator default from `^0.7.0` to `^0.8.0` in
   `tool/create_consumer_app.dart` (4 places), `README.md` and its tests, in
   the same step as publishing (the new version must exist on pub.dev first).
3. Tag `v0.8.0`, publish, create the GitHub release with this text.
