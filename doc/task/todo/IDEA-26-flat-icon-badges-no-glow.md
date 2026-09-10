---
id: IDEA-26
title: "EmptyStatePlaceholder/ShopItemCard: icon không có glow/backdrop mềm như AvatarFrame"
type: idea
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork D)
---

## Ý tưởng
- `EmptyStatePlaceholder` (`empty_state_placeholder.dart`): icon nằm trong
  1 `Container` tròn màu `NeonTheme.cardAlt`, KHÔNG `boxShadow` nào —
  hoàn toàn phẳng.
- `ShopItemCard` (`shop_item_card.dart`): icon nổi trực tiếp trên nền
  `PanelCard`, không có backdrop tròn hay glow nào cả.

Trong khi `AvatarFrame` (`avatar_frame.dart`) dùng viền màu + `NeonTheme.glow(color, blur: 12)` cho MỌI icon/avatar nó bọc — tạo cảm giác "phát sáng nhẹ" đặc trưng của kit. Cả 2 widget trên đều hiển thị icon nhưng không có cùng treatment, đọc "rẻ" hơn hẳn khi đặt cạnh nhau trong `WidgetShowcaseScreen`.

## Vì sao cần
Đây là bất nhất quán thẩm mỹ dễ thấy — 2 widget hiển thị icon trong 1 khối
tròn/card, nhưng chỉ 1 kiểu (`AvatarFrame`) có glow. Thêm glow nhẹ vào 2
nơi còn lại sẽ khiến cả 3 đọc như "cùng 1 hệ thống thiết kế" thay vì 2
phong cách khác nhau.

## Đề xuất
- `EmptyStatePlaceholder`: thêm `boxShadow: NeonTheme.glow(color, blur: 10, intensity: 0.4)` (nhẹ hơn `AvatarFrame` vì đây là trạng thái "rỗng", không nên quá nổi bật) vào `Container` bọc icon.
- `ShopItemCard`: bọc `Icon` trong 1 `Container` tròn nhỏ (giống `EmptyStatePlaceholder`) kèm glow nhẹ, thay vì icon nổi trần trên card.

## Acceptance criteria
- [ ] Cả 2 widget có glow/backdrop nhất quán với `AvatarFrame`'s treatment.
- [ ] Golden test (nếu có) cập nhật khớp thay đổi.

## Ghi chú độ tin cậy
Thấp — thuần cải thiện thẩm mỹ chủ quan, không sai gì hiện tại. Nên xem
trực tiếp trên `WidgetShowcaseScreen` trước/sau để xác nhận thực sự đẹp
hơn (glow quá nhiều nơi có thể phản tác dụng, trông rối) trước khi áp dụng
tràn lan.
