## 0.2.0

- Added `BackupRestorePanel` widget (IDEA-31): puts `StorageService.exportAll()`/`importAll()` and `save_integrity.dart`'s HMAC sign/verify on screen. Caller supplies `secret`, `onExport(signedJson)` and `onImport() -> signedJson?` seams (the actual file/QR/share mechanism stays app-specific, same convention as `CloudSaveProvider`); a checksum-mismatch or malformed import shows an inline error instead of crashing, and a restore is gated behind a confirm dialog since it overwrites the whole local save.
- Added `LocalScoreboardService` (IDEA-30): a local, single-device high-score table. `submitScore(playerLabel, score)` ranks a new submission against every previous one on the device (ties break by earlier submission); `topN(n)` returns `LeaderboardEntry` directly (rank + formatted score via `fmtNum`), ready to feed straight into `LeaderboardList` with no caller-side transform. Capped (default 50 rows) — lowest score dropped as soon as it would rank last.
- Added `DailyQuestService` (IDEA-29): a caller-declared daily/weekly quest tracker — the third reset-cadence mechanism alongside the permanent `AchievementService` and the fixed-calendar `DailyLoginService`. `register(id, targetCount, {period})` declares a quest once; `incrementProgress`/`isCompleted`/`claim` track it per `QuestPeriod` (`daily`/`weekly`), resetting automatically on the `ClampedClock`-backed period boundary so winding the device clock back can't re-claim an already-claimed quest.
- `RemoteConfigService` (ENH-58): partial remote responses now merge key-by-key on top of asset defaults instead of replacing the whole config (a response missing/omitting a key no longer wipes its asset fallback); added a read-only `snapshot` getter and a `source` getter (`RemoteConfigSource`: `assetOnly`/`remoteMerged`/`remoteFailed`) to inspect where the current config came from.
- Added reactive `EconomyWallet` with atomic earn/spend and transaction idempotency.
- Added `GameSessionController` for typed game session state, nested pause reasons and lifecycle bridging.
- Added typed `SdkResult` success/failure contracts for public service APIs.
- Added `SaveMigrationRegistry` for validated multi-hop save upgrades with copy-on-write migration.
- Added `AsyncActionGuard` for keyed single-flight and ordered exclusive actions.
- Added the GetX lifecycle coordinator for ordered, isolated background/resume hooks with storage flush and audio handling.
- Added a deterministic consumer contract-test fixture and bootstrap verification harness through the public package entrypoint.
- Core services: `ClampedClock`-backed cheat-proof offline earnings (`OfflineProgressionService`), `VersionedJsonStore`, `PerformanceTierService`, `DailyLoginService`, `EnergyService`, `CrashReporter` seam, plus reduced-motion support (`NeonTheme.reducedMotion`) applied across every animated widget in the kit.
- Widget kit grown from 21 to 40 widgets: new progress/reward widgets (`CountdownChip`, `PaginatedDotsIndicator`, `CoinFlyOverlay`, `DailyLoginCalendarWidget`, `EnergyBar`), new layout/card widgets (`RibbonBadge`, `ShopItemCard`, `VictoryCardTemplate`, `LeaderboardList`), new feedback/overlay widgets (`ConfettiOverlay`, `FloatingComboText`, `NetworkStatusBanner`, `ShimmerPlaceholder`, `SpotlightOverlay`), a game-specific `LevelSelectGrid`, and a game-feel/juice set (`SquashStretch`, `ScreenShake`, `ComboHeatBackground`).
- New Flame starter template (`RoyGame`) and `FlameTrackedOverlay` for pinning Flutter widgets to in-game world positions.
- Notable bug fixes: Flame camera-anchor/world-origin mismatch (BUG topLeft anchor), `ClampedClock` rewind resistance extended to `VersionedJsonStore`, several real-device narrow-width `RenderFlex` overflows (`CurrencyCounter`, `LevelSelectGrid`), `CommonButton` height rebalanced, `RewardPopup`'s lazily-initialized burst controller.

## 0.1.0

- Initial release: core services (storage, i18n, audio, haptics, local reminders, theme tokens) and a 21-widget casual-game UI kit (buttons, overlays, progress/reward, layout & cards).
