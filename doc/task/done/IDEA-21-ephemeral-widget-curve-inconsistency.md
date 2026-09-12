---
id: IDEA-21
title: "Curve 'juice' không nhất quán giữa các widget feedback ngắn hạn (ToastBanner bouncy, FloatingComboText/NetworkStatusBanner không)"
type: idea
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork B)
---

## Vị trí
So sánh entrance curve giữa các widget "feedback ngắn hạn, tự dọn mình"
trong `lib/presentation/widgets/common/`:
- `toast_banner.dart`: `Curves.easeOutBack` (có overshoot/bounce rõ).
- `floating_combo_text.dart`: rise dùng `Curves.easeOut` (không bounce), fade dùng `Curves.easeIn`.
- `network_status_banner.dart`: `AnimatedSize`/`AnimatedOpacity` mặc định (curve tuyến tính, không set `curve:` — implicit animation Flutter mặc định `Curves.linear` nếu không truyền).
- `confetti_overlay.dart`: motion vật lý thuần (rơi/xoay), không áp dụng khái niệm "curve vào" theo nghĩa UI.

## Hiện trạng
Không có "house style" thống nhất cho việc widget ephemeral nào nên bouncy
(có overshoot, cảm giác vui/playful) và widget nào nên phẳng/nghiêm túc
(no-bounce, cảm giác thông báo/cảnh báo). Hiện tại lựa chọn dường như ngẫu
nhiên theo từng widget được viết lúc nào, không theo 1 quy tắc rõ ràng.

## Vì sao cần
1 bộ kit "xịn sò" thường có ngôn ngữ chuyển động (motion language) nhất
quán — cùng 1 loại khoảnh khắc (reward/celebration) nên dùng cùng 1 "cảm
giác" curve, khác với loại khoảnh khắc khác (cảnh báo/thông tin nghiêm túc
như `NetworkStatusBanner`). Hiện thiếu 1 quy ước rõ ràng khiến các
widget mới thêm sau này (như `WheelSpinner`, `GameOverCardTemplate`) không
có chuẩn để theo.

## Đề xuất
Ghi 1 quy ước ngắn vào doc comment của `neon_theme.dart` (cạnh
`reducedMotion`), hoặc CLAUDE.md's "Theme" section: "curve có overshoot
(`Curves.easeOutBack`/tương tự) cho khoảnh khắc ăn mừng/reward (confetti,
combo, popup thắng); curve phẳng (`easeOut`/`easeInOut`, không overshoot)
cho thông báo trạng thái/cảnh báo (network banner, toast lỗi)". Sau đó rà
lại từng widget xem có lệch quy ước không (vd `ToastBanner.show` dùng
chung 1 hàm cho cả toast "Confirmed" (ăn mừng nhẹ) lẫn network warning-style
message — nên xem xét có cần 2 preset curve theo `color`/mức độ nghiêm
trọng hay không).

## Acceptance criteria
- [x] Quy ước curve được ghi lại thành văn bản rõ ràng (doc comment hoặc CLAUDE.md).
- [x] Rà soát từng widget đối chiếu quy ước, liệt kê cụ thể cái nào cần đổi (nếu có) trong `## Quyết định` lúc làm task này.

## Ghi chú độ tin cậy
Thấp — đây là quan sát "thiếu nhất quán", không phải bug hay yêu cầu cụ thể.
Giá trị chủ yếu là làm rõ định hướng thiết kế cho các widget tương lai, có
thể gộp chung vào lúc làm ENH-26/ENH-27 ở trên thay vì làm riêng 1 task.

## Quyết định
Ghi quy ước thành doc comment ngay cạnh `NeonTheme.reducedMotion`
(`lib/core/neon_theme.dart`) — không phải CLAUDE.md, vì đây là quy ước kỹ
thuật cụ thể gắn với `NeonTheme`, hợp lý nhất khi đọc code (IDE hiện tooltip
ngay tại nơi dùng), CLAUDE.md's "Theme" section chỉ tóm tắt token chung.

Bảng rà soát (celebration/reward = bouncy `easeOutBack`; status/warning =
phẳng, không overshoot; physics = miễn áp dụng khái niệm curve vào):

| Widget | Loại | Curve hiện tại | Kết luận |
|---|---|---|---|
| `ToastBanner` | celebration (mặc định) | `easeOutBack` vào, `easeIn` ra | Đúng quy ước |
| `FloatingComboText` | celebration | `easeOutBack` scale pop-in (IDEA-19) | Đúng quy ước |
| `RewardPopup`/`NeonDialog` | celebration | `easeOutBack` entrance | Đúng quy ước |
| `RibbonBadge` | celebration | `easeOutBack` pop-in (IDEA-27) | Đúng quy ước |
| `StreakCounter`/`ProgressBarStars`/`IconBadgeButton` | celebration | `easeOutBack` pop khi đổi trạng thái | Đúng quy ước |
| `SpotlightOverlay` (callout) | celebration | `easeOutBack` entrance | Đúng quy ước |
| `SpotlightOverlay` (scrim/dim) | status (không phải reward) | `easeOut` phẳng | Đúng quy ước |
| `NetworkStatusBanner` | status/warning | KHÔNG set `curve:` → implicit `Curves.linear` | **Lệch quy ước — đã sửa**: thêm `curve: Curves.easeOut` tường minh cho cả `AnimatedSize`/`AnimatedOpacity`. |
| `ConfettiOverlay` | physics | không áp dụng | Miễn, đúng như ghi chú gốc |
| `CoinFlyOverlay` | physics | không áp dụng (quỹ đạo bezier + squash, IDEA-22) | Miễn |

Vấn đề mở KHÔNG giải quyết trong task này (nằm ngoài phạm vi "docs +
audit" của P3/effort S/độ tin cậy thấp): `ToastBanner` dùng chung 1
`easeOutBack` cho mọi mức độ nghiêm trọng, kể cả khi hiển thị message dạng
cảnh báo/lỗi (không chỉ "Confirmed" ăn mừng nhẹ) — có nên tách 2 preset
curve theo `color`/severity hay không là 1 quyết định thiết kế lớn hơn,
để dành cho 1 task riêng nếu thực sự cần trong tương lai, không tự ý mở
rộng phạm vi ở đây.

Test: 1 test mới (`NetworkStatusBanner` dùng curve tường minh `easeOut`,
không phải `Curves.linear` mặc định). `flutter analyze` sạch cả root +
`example/`. `flutter test --exclude-tags slow`: tất cả pass, không
regression (494→495).

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Feedback & Overlay → Network Banner → bấm "Go offline"/"Go online" vài
lần, banner hiện/ẩn đúng nội dung ("No internet connection"), không
exception trong logcat.
