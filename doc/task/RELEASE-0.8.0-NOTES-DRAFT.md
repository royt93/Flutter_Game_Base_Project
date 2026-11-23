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

## Behavior changes you may notice

Accessibility (screen readers and touch targets). Layout changes are small:

- `AppVersionGateOverlay`, `SpotlightOverlay`, `NeonDialog.overlay` and
  `NeonDialog.overlaySlot` (so `PauseOverlay`) now hide the app behind them from
  TalkBack and VoiceOver. Before, a screen reader could still reach and activate
  the blocked app. `overlaySlot` only blocks while it shows a panel.
  `LoadingOverlay` is unchanged on purpose.
- `ExpandablePanel`'s header is one button named by its text. Before, a screen
  reader found an unnamed button followed by a separate tappable text node.
- `EventCalendarCard`'s open button is 48x48 (was 40x40), so each event row is
  about 3px taller.
- `CollectionAlbumPanel`'s filter chips are 44dp tall (were 33dp), so the panel
  is 11dp taller.

Daily systems use the UTC day (documented, not changed): `DailyLoginService`,
`DailyQuestService`, `SeededChallengeService` and `streakExpiringReminderDelay`
roll over at 00:00 UTC, which is 07:00 local in UTC+7 and 16:00 in UTC-8. A game
that wants a local-midnight reset has to implement it itself. A new test locks
the boundary.

Numeric fixes: `fnv1aHash` and `asIntOr` now return the same result everywhere
(no change on Android or iOS); persisted counters share one overflow limit.

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
  performance-budget checks pass, and CI (analyze-test, quality-gate,
  consumer-smoke) is green on the release commit. Goldens are generated on
  Linux; the 19 baselines changed by the accessibility fixes were regenerated
  through the repository's workflow.
- Device evidence is from a Google Pixel 7 Pro and a Samsung Galaxy S24 Ultra
  (both Android 17): the Match-3 flow (tutorial, booster, pause, restart), the
  Flame pause bridge, and the Match-3 and pause flows again after the overlay
  accessibility change (S24 Ultra). Not covered on a device: the result-card
  share sheet, a real app background (only simulated lifecycle events), and
  TalkBack or VoiceOver themselves. The accessibility claims come from the
  semantics tree in tests, not from a screen reader.
- No backend, store or ad network behavior is claimed. See
  `docs/qa/capability_evidence_matrix.md` and `docs/qa/device_matrix.md`.

## Before publishing (owner steps, not done here)

See `doc/task/RELEASE-0.8.0-PUBLISH-PROCEDURE.md`. In short: tag the commit CI
went green on, publish from a git archive of the tag, and only after 0.8.0 is on
pub.dev apply `doc/task/evidence/RELEASE-0.8.0-generator-default.patch`
(`^0.7.0` to `^0.8.0` in the consumer generator).
