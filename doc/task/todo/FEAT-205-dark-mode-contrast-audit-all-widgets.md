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
- **Pha 2 (probe 15 widget, 2026-11-14):** dựng fixture theo trạng thái viewport sweep và app `ThemeData`, audit light/dark. Source confirms below-AA candidates on flat opaque surfaces in light theme: `StreakRepairDialog` subtitle (`NeonTheme.inkSoft` on `NeonTheme.card`, 3.92:1); `PrestigeConfirmationCard` message (`inkSoft/card`, 3.92:1) and multiplier labels (`inkSoft/cardAlt`, 3.40:1); `RewardPopup` message (`inkSoft/card`, 3.92:1); `SupportDiagnosticsCard` privacy note (`inkSoft/card`, 3.92:1); `GameOverCardTemplate` message (`inkSoft` inside `PanelCard`, 3.92:1). These are active text, not disabled controls; measurements repeat with app-equivalent theme. Remediation tracked separately in BUG-120 through BUG-124; do not alter global tokens. `RankPromotionDialog` white-on-tier and `StrokeText`/custom-painted titles need renderer-specific validation; exclude from confirmed list for now. Probe remains exploratory, not a CI baseline.

## Rủi ro
Nền có gradient/shader/ảnh không tính được bằng alpha-blend; harness bỏ qua `DecoratedBox` có gradient/image và chưa xử lý `CustomPaint`, shader hay mọi loại overlay/layer. Kết quả probe không được coi là WCAG certification; chỉ dùng để sàng lọc widget có nền phẳng đã nhận diện.
- Text không có màu explicit hoặc kế thừa style có thể bị bỏ qua; harness chỉ kiểm `Text` có thể resolve màu foreground.
- Disabled controls cần được loại khỏi audit theo trạng thái widget; chưa có cơ chế loại trừ tổng quát.
- Font size bold large-text threshold dùng Flutter logical pixel approximation (18.67sp bold / 24sp regular).
- `Icon` threshold 3.0 chưa được thực hiện trong pha 1.
- Duy trì probe/baseline lâu dài chỉ sau khi ổn định cách xác định effective background trên widget thật.

## Quan hệ
Bổ sung FEAT-201 (lint tĩnh màu cố định): lint bắt chỗ viết, audit này bắt kết quả render.
