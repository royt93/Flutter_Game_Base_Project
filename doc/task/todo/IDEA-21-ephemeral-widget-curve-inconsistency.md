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
- [ ] Quy ước curve được ghi lại thành văn bản rõ ràng (doc comment hoặc CLAUDE.md).
- [ ] Rà soát từng widget đối chiếu quy ước, liệt kê cụ thể cái nào cần đổi (nếu có) trong `## Quyết định` lúc làm task này.

## Ghi chú độ tin cậy
Thấp — đây là quan sát "thiếu nhất quán", không phải bug hay yêu cầu cụ thể.
Giá trị chủ yếu là làm rõ định hướng thiết kế cho các widget tương lai, có
thể gộp chung vào lúc làm ENH-26/ENH-27 ở trên thay vì làm riêng 1 task.
