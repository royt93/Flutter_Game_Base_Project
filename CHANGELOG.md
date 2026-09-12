## 0.2.0

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
