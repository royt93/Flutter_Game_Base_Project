---
id: ENH-14
title: "TooltipBubble chưa có test file riêng (sót lại từ BUG-10)"
type: enhance
priority: P2
effort: S
verified: true
source: Claude, audit round 2 (fork agent), verify lại code thật
---

## Hiện trạng
BUG-10 (đã đóng) liệt kê 20 widget cần test — `TooltipBubble` là widget duy
nhất bị sót. Hiện chỉ được exercise gián tiếp qua smoke test "renders without
throwing" của `example/`, chưa có unit test riêng cho logic nub-direction/vị
trí (`CustomPainter`-based) của chính widget.

## Đề xuất
Thêm `test/widget/common/tooltip_bubble_test.dart`: render với từng
`TooltipPointerDirection` (up/down/left/right — kiểm tra tên enum thật trong
`tooltip_bubble.dart`), verify painter vẽ đúng hướng nub, verify
`TooltipBubble.text(...)` constructor phụ hoạt động đúng, verify
`reducedMotion` (nếu widget có animation nào) không throw.

## Acceptance criteria
- [ ] `test/widget/common/tooltip_bubble_test.dart` tồn tại, cover mọi
      `TooltipPointerDirection`.
