---
id: FEAT-200
title: "Responsive viewport sweep: mọi widget trong common/ không overflow ở màn nhỏ và landscape"
type: feature
layer: test/support + test/widget/common
priority: P1
effort: L
source: "BUG-103, BUG-104 + PauseOverlay overflow cùng một lớp lỗi; chưa có gate bắt"
---

## Vấn đề
`golden_matrix.dart` (FEAT-69) quét dark/locale/RTL/textScale/reducedMotion nhưng **mọi combo dùng một viewport mặc định**. Vì vậy PauseOverlay (landscape), GameDemo FAB (landscape) và StreakRepairDialog (320dp) đều lọt qua và chỉ lộ khi test tay.

## Phạm vi
- Thêm `ViewportCase` (320x480, 360x640, 568x320, 640x320, tablet 768x1024) vào `test/support/`, tách khỏi `GoldenMatrixCase` để không nhân số golden.
- Test sweep chỉ kiểm "không `takeException`, panel nằm trong viewport", **không so golden**.
- Mỗi widget cần fixture dựng tối thiểu; widget lấy từ barrel `common_widgets.dart`.

## Pha
1. Khung + 5 widget dạng dialog/overlay (PauseOverlay, StreakRepairDialog, ConfirmDialog, RewardPopup, PrestigeConfirmationCard) làm mẫu.
2. Phần còn lại của common/; widget cố tình không hỗ trợ viewport nhỏ phải có lý do ghi trong allowlist.
3. Gắn vào CI (`flutter test` root đã chạy, không cần job mới).

## Tiến độ
- [x] Pha 1 khung: `test/support/viewport_sweep.dart` (`ViewportCase`, `runViewportSweep`) và `test/widget/common/viewport_sweep_test.dart` với StreakRepairDialog (1x và 2x text), PrestigeConfirmationCard, RewardPopup, SupportDiagnosticsCard. Đã chứng minh: hoàn nguyên tạm bug width 320 thì 2 test đỏ.
- [x] Pha 2a: thêm GameOverCardTemplate, VictoryCardTemplate, MilestoneCelebrationDialog (xanh) và StreakShieldCard (lộ lỗi thật BUG-107, đã sửa và đóng).
- [x] Pha 2b (2026-11-13): thêm CloudSaveStatusCard, ConnectivityStatusCard, OutboxQueueStatusCard, AnnouncementPreviewCard, FlashSaleOfferCard, ComebackBundleCard, RankPromotionDialog (5 viewport) và nhóm text scale 2.0 ở 320x480 / 568x320 cho 6 widget. Toàn bộ 22 test xanh: lần này KHÔNG lộ lỗi mới (các card trạng thái dạng Column/Wrap đã co giãn tốt). Tổng 16 widget được sweep, 1 lỗi thật bắt được ở cả đợt (BUG-107).
- [x] Pha 2c (2026-11-13): thêm 12 widget (ShopItemCard, EnergyBar, OfflineEarningsPopup, PrestigeReadinessCard, SeasonEventBanner, TieredLeaderboardRow, VipPerkProgressRow, InboxMessageCard, RewardedAdResultCard, SyncStatusCard, PlayerDataRightsPanel, ToastBanner), mỗi cái ở 5 viewport và ở chữ 2.0x tại 320x480 / 568x320. Lộ 3 lỗi thật cùng loại (tràn ngang 320dp + 2.0x), đã sửa (BUG-114). Tổng 28 widget được sweep.
- [x] Pha 2d (2026-11-13): thêm 11 widget panel/list (QuestBoardPanel, RewardChoicePanel, ProfileStatsCard, CheckpointResumeCard, EventCalendarCard, GiftLivesRequestCard, TeamRosterList, CollectionAlbumPanel, BackupRestorePanel, ReminderPreferencesPanel, ConsentPreferencesPanel). Lộ 1 lỗi thật (BUG-115, CollectionAlbumPanel). Tổng 39 widget được sweep trên 169; còn khoảng 130, phần lớn là widget cần Flame/controller/session hoặc overlay toàn màn hình.
- [x] Pha 2e (2026-11-14): thêm 10 widget display tổng quát (`BadgeDot`, `CircularProgressRing`, `CurrencyCounter`, `ProgressBarStars`, `StarRating`, `PaginatedDotsIndicator`, `SectionHeader`, `CooldownCountdownChip`, `CountdownChip`, `NextRewardTeaserChip`) vào sweep mặc định và 320x480/568x320 ở text scale 2.0. Tổng 49 widget; full sweep 88 tests pass.
- [x] Pha 2f (2026-11-14): thêm `EmptyStatePlaceholder` và `EventSchemaAuditCard` vào 5 viewport mặc định; full sweep 90 tests pass. Tổng 51/170 widget; không lộ overflow.
- [x] FEAT-202 reuse case thật: `EnergyBar` refill target mở rộng 28dp → 48dp; existing test checks 48×48, viewport sweep still passes.
- [x] Pha 2g (2026-11-14): thêm `BatterySaverIndicator` và `StackedAvatarGroup` với sweep mặc định và 320dp/landscape ở text scale 2.0. Full sweep 94 tests pass; tổng coverage 53/170 widget.
- [x] Pha 2h (2026-11-14): thêm `ContentPackStatusCard`, `DeepLinkResultCard`, `EconomyCertificateStatusCard` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 100 tests pass; tổng coverage 56/170 widget.
- [x] Pha 2i (2026-11-14): thêm `ContrastPreviewCard`, `AvatarFrame`, `PanelCard` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 106 tests pass; tổng coverage 59/170 widget.
- [x] Pha 2j (2026-11-14): thêm `TooltipBubble`, `CommonListTile`, `SoundToggleFab` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 112 tests pass; tổng coverage 62/170 widget.
- [x] Pha 2k (2026-11-14): thêm `AsyncCommonButton`, `CandySearchBar` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 116 tests pass; tổng coverage 64/170 widget.
- [x] Pha 2l (2026-11-14): thêm `DailyLoginCalendarWidget` và `AvatarFrameSelector` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 120 tests pass; tổng coverage 66/170 widget.
- [x] Pha 2m (2026-11-14): thêm `FriendRequestTile`, `LevelGoalTracker`, `QuestProgressPill` ở sweep mặc định và 320dp/landscape với text 2.0x. Lộ overflow thật BUG-126 (`FriendRequestTile` 568×320 ở 2× text), đã sửa bằng xếp ngang hai nút từ 480dp trở lên. Full sweep 126 tests pass; tổng coverage 69/170 widget.
- [x] Pha 2n (2026-11-14): thêm `FilterChipRow` và `ContentRevisionHistoryPanel` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 130 tests pass; tổng coverage 71/170 widget.
- [x] Pha 2o (2026-11-14): thêm `CandySlider`, `DailyOfferStack` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 134 tests pass; tổng coverage 73/170 widget.
- [x] Pha 2p (2026-11-14): thêm `InventoryGrid`, `LevelPathMapTile` ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 138 tests pass; tổng coverage 75/170 widget.
- [x] Pha 2q (2026-11-14): thêm `BoosterSlotBar`, `StreakCounter`, `WinStreakFlameHud` ở sweep mặc định và 320dp/landscape với text 2.0x. Lộ overflow thật BUG-127 (`WinStreakFlameHud` 320dp ở 2× text), sửa co chữ bằng `FittedBox.scaleDown`. Full sweep 144 tests pass; tổng coverage 80/170 widget.
- [x] Pha 2r (2026-11-14): thêm `CoinMultiplierWheel` (không auto-start), `BadgeShowcaseStrip` (read-only) và `AnalyticsQueueStatusCard` (không consent) ở sweep mặc định và 320dp/landscape với text 2.0x. Full sweep 150 tests pass; tổng coverage 83/170 widget.
- [x] Pha 2s (2026-11-14): thêm `ConsentBanner` với service setup/reset riêng cho từng viewport; full sweep 157 tests pass, `consent_banner_test.dart` và analyzer pass. Sweep lộ BUG-128: dialog tràn ở màn thấp và 2× text. Sửa shared `NeonDialog.panel` bằng max-height theo viewport và scroll content. Tổng coverage 84/170 widget.
- [ ] Mở rộng sang phần còn lại của `common/` (khoảng 86 widget): làm theo nhóm, widget cố tình không hỗ trợ viewport nhỏ phải có lý do trong allowlist.
- Ghi chú: `PauseOverlay` đã có test landscape riêng; `showConfirmDialog` là route, không phải widget nên ngoài phạm vi sweep.

## Tiêu chí xong
- Sweep xanh; allowlist có lý do từng dòng.
- Thử đưa lại bug cũ (width cố định 320) thì test đỏ.

## Rủi ro
Có thể lộ nhiều lỗi cũ cùng lúc; xử lý bằng cách tách BUG-xxx riêng cho mỗi widget lỗi, không sửa gộp.
