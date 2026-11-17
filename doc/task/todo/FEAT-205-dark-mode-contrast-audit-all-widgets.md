---
id: FEAT-205
title: "Dark-mode contrast audit: chữ thật trên nền thật của mọi widget ở NeonTheme.dark"
type: feature
layer: test/support + test/widget/common
priority: P2
effort: L
source: "ENH-103 (locked token) và ENH-104 (prestige card): token cặp đúng nhưng widget dùng màu cố định hoặc tint, validator hiện chỉ kiểm cặp token"
---

## Vấn đề
`validateNeonThemeContrast` kiểm các cặp token (ink/card, locked border/fill...) nhưng không kiểm chữ **thực sự render** trên nền **thực sự render**. ENH-104 lộ ra vì chữ `Colors.orange` trên tint alpha 0.12 chỉ đạt 1.96:1 ở light, không cặp token nào sai.

## Phạm vi
- Harness `test/support/contrast_audit.dart`: pump widget ở light và dark, duyệt cây `Text`/`Icon`, lấy màu chữ và màu nền hiệu dụng (alpha-blend các ancestor `DecoratedBox`/`Container`/`Material`), báo cặp dưới 4.5:1 (chữ) hoặc 3.0:1 (icon, cỡ lớn).
- Chỉ kiểm màu mà widget tự đặt; bỏ qua widget `Disabled` (WCAG miễn) bằng cờ.
- Báo cáo danh sách vi phạm ban đầu; mỗi vi phạm mở BUG/ENH riêng (mẫu ENH-104).

## Tiêu chí xong
- Chạy được trên nhóm widget mẫu đã sửa (prestige card xanh) và bắt lại lỗi cũ khi hoàn nguyên tạm.
- Danh sách vi phạm còn lại được ghi baseline với lý do hoặc task.

## Tiến độ audit
- **Pha 1 revision (2026-11-14):** harness `test/support/contrast_audit.dart` audit `RichText`/`TextSpan` đã resolve style, màu tổ tiên từ `Material`/`ColoredBox`/`DecoratedBox` phẳng, alpha blend, ngưỡng normal/large text; bỏ qua gradient/image và glyph nằm trong `Icon`. 8 widget tests pass: nền tint, kế thừa `DefaultTextStyle`, `RichText` spans, gradient skip, PrestigeConfirmationCard thật ở light/dark và regression fixture ENH-104. `flutter analyze --no-pub` sạch.
- **Pha 2 (probe 15 widget, 2026-11-14):** dựng fixture theo trạng thái viewport sweep và app `ThemeData`, audit light/dark. Source confirms below-AA candidates on flat opaque surfaces in light theme: `StreakRepairDialog` subtitle (`NeonTheme.inkSoft` on `NeonTheme.card`, 3.92:1); `PrestigeConfirmationCard` message (`inkSoft/card`, 3.92:1) and multiplier labels (`inkSoft/cardAlt`, 3.40:1); `RewardPopup` message (`inkSoft/card`, 3.92:1); `SupportDiagnosticsCard` privacy note (`inkSoft/card`, 3.92:1); `GameOverCardTemplate` message (`inkSoft` inside `PanelCard`, 3.92:1). These are active text, not disabled controls; measurements repeat with app-equivalent theme. Remediation tracked in BUG-120 through BUG-124. All five local text-color fixes and light/dark contrast assertions now pass; BUG-121/123 remain open until Linux golden baselines are regenerated. No global token changed. `RankPromotionDialog` white-on-tier and `StrokeText`/custom-painted titles need renderer-specific validation; exclude from confirmed list for now. Probe remains exploratory, not a CI baseline.

- **Pha 3 probe (2026-11-14):** `VipPerkProgressRow` only. Active `Next Tier Progress` and `Perks & Privileges` resolve to 3.92:1 on opaque `NeonTheme.card` in light mode; both pass in dark mode. Source confirms text is outside gradient badge and disabled states. Tracked as BUG-125; no color changed in probe. Focused probe and harness tests pass.

## Rủi ro
Nền có gradient/shader/ảnh không tính được bằng alpha-blend; harness bỏ qua `DecoratedBox` có gradient/image và chưa xử lý `CustomPaint`, shader hay mọi loại overlay/layer. Kết quả probe không được coi là WCAG certification; chỉ dùng để sàng lọc widget có nền phẳng đã nhận diện.
- Text không có màu explicit hoặc kế thừa style có thể bị bỏ qua; harness chỉ kiểm `Text` có thể resolve màu foreground.
- Disabled controls cần được loại khỏi audit theo trạng thái widget; chưa có cơ chế loại trừ tổng quát.
- Font size bold large-text threshold dùng Flutter logical pixel approximation (18.67sp bold / 24sp regular).
- `Icon` threshold 3.0 chưa được thực hiện trong pha 1.
- Duy trì probe/baseline lâu dài chỉ sau khi ổn định cách xác định effective background trên widget thật.

## Quan hệ
Bổ sung FEAT-201 (lint tĩnh màu cố định): lint bắt chỗ viết, audit này bắt kết quả render.

## Mở rộng harness (2026-11-17)
- Probe 13 widget hiển thị đơn giản ở light/dark: lộ gốc lỗi là token `NeonTheme.inkSoft` light `#8579B0` (3.92:1 trên `card`, 3.40:1 trên `cardAlt`), dùng ở 136 chỗ/64 file (`NextRewardTeaserChip`, `EmptyStatePlaceholder` là hai ca bị bắt). Dark đạt AA.
- Quyết định người dùng: đổi token một lần thay vì sửa từng widget. `_inkSoftLight` -> `#6F639E` (5.31:1 trên `card`, 4.61:1 trên `cardAlt`). Test validator đổi từ "ghi nhận lỗi đã biết" sang khẳng định `inkSoft` đạt AA cả hai theme.
- Probe `Text` không màu trong `PanelCard`/`TooltipBubble` dark báo 1.03:1 là artifact của fixture probe (chữ lấy màu mặc định Material), không phải lỗi widget.
- Golden light có dùng `inkSoft` đổi pixel; baseline phải sinh lại bằng workflow `regenerate-goldens` (Linux), không từ macOS.
- Chưa làm: ngưỡng icon 3.0:1, quét các nhóm widget còn lại.

## Probe nhóm 2c/2d (2026-11-17, 26 widget, light + dark)
- Light: 12 widget có chữ dưới AA, gốc chung là **màu accent dùng làm màu chữ trên `card`/`cardAlt`**: `OfflineEarningsPopup` "74,663" 1.79; `SeasonEventBanner` "3d 0h" 2.82; `VipPerkProgressRow` "View Perks" 2.82, "300 / 500 pts" 1.79; `PlayerDataRightsPanel` "Export my data" 1.77; `ProfileStatsCard` "Lv 42" 3.25; `CheckpointResumeCard` "Start new game" 1.77; `EventCalendarCard` "Fri"/"Live" 1.69; `GiftLivesRequestCard` "Send Life" 2.14; `TeamRosterList` 1.59 đến 1.77; `CollectionAlbumPanel` 1.67 đến 3.25; `BackupRestorePanel` "Export save" 1.77; `ConsentPreferencesPanel` "Allow" 1.77.
- Đo token accent trên `cardAlt`/`card`: cyan 1.77/2.04, orange 1.77/2.04, lime 1.66/1.92, gold 1.56/1.79, yellow 1.25/1.44, magenta 2.20/2.53, blue 2.22/2.56, red 2.41/2.78, purple 2.82/3.25. Không accent nào đạt 4.5:1 ở light; ví dụ nút `CommonButton.secondary` dùng `c` làm màu chữ trên `cardAlt`.
- Dark: các ca 1.03 ở `PrestigeReadinessCard`, `RewardedAdResultCard`, `SyncStatusCard`, `ReminderPreferencesPanel` là artifact fixture probe (chữ không đặt màu lấy mặc định Material), không phải lỗi. Còn thật: "Lv 42" 3.25, "All" 3.25, "Send Life" 2.14.
- Chưa sửa: cần quyết định thiết kế (token chữ tối cho accent, hay đổi chữ sang `ink`), vì ảnh hưởng nhiều widget và golden.

## Sửa chữ accent (2026-11-17, quyết định người dùng: token chữ tối)
- Thêm `NeonTheme.accentText(Color)` (một hàm theo theme thay vì chín token): tối/sáng accent vừa đủ để đạt 4.5:1 trên cả `card` và `cardAlt`; giữ nguyên nếu đã đạt (mọi accent ở dark). Test: 18 ca (9 accent x light/dark) + giữ nguyên dark cyan.
- Áp cho chữ (không đụng icon/viền/nền) ở 9 widget: `CommonButton` secondary, `OfflineEarningsPopup`, `SeasonEventBanner`, `VipPerkProgressRow`, `ProfileStatsCard`, `EventCalendarCard`, `TeamRosterList`, `CollectionAlbumPanel`.
- Probe lại 2c/2d: 12 widget vi phạm xuống 4. Hai ca accent còn lại (`_rarityColor`, `roleColor`) đã sửa sau đó.
- **Còn lại, khác loại:** chữ trắng trên nền accent đặc, `ProfileStatsCard` "Lv 42" 3.25, `CollectionAlbumPanel` "All" 3.25, `GiftLivesRequestCard` "Send Life" 2.14. Sửa cần đổi màu nền nút/badge hoặc màu chữ, là quyết định thiết kế riêng.

## Chữ trắng trên nền accent (2026-11-17)
- Thêm `NeonTheme.fillForWhiteText(Color)`: tối nền accent vừa đủ để chữ trắng đạt 4.5:1, giữ nguyên nếu đã đạt. Test 10 ca (9 accent + giữ nguyên nền đã đủ tối).
- Áp cho `XpLevelHeader` (badge cấp, hiển thị "Lv 42" ở `ProfileStatsCard`), `CollectionAlbumPanel` (chip lọc đang chọn, "All") và `GiftLivesRequestCard` (nút "Send Life"). Probe lại: 3 widget sạch. Nhóm 2c/2d hết vi phạm nền phẳng đã đo ở light.
- Còn lại: ngưỡng icon 3.0:1 và các nhóm widget chưa quét.
