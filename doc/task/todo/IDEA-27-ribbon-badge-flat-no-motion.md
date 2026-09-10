---
id: IDEA-27
title: "RibbonBadge phẳng hoàn toàn (màu đặc, không sheen/shine), không có entrance motion"
type: idea
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork D)
---

## Ý tưởng
`RibbonBadge` (`lib/presentation/widgets/common/ribbon_badge.dart`) vẽ dải
ruy băng chéo bằng 1 `Container(color: c, ...)` — màu đặc phẳng tuyệt đối,
không gradient/shine, và không có bất kỳ animation nào (xuất hiện tức thì
cùng lúc với `child`).

## Vì sao cần
"NEW"/"SALE"/"BEST VALUE" là nhãn có mục đích THU HÚT SỰ CHÚ Ý — nhãn tĩnh
phẳng hoàn toàn không thực hiện tốt vai trò đó so với 1 nhãn có sheen nhẹ
hoặc pop-in khi xuất hiện. Đây cũng là widget duy nhất trong nhóm
"Layout & Cards" hoàn toàn không có chút gradient/glow nào trong khi hầu
hết widget khác trong kit đều có.

## Đề xuất
- Thêm 1 gradient chéo nhẹ (`LinearGradient` 2 sắc độ của cùng màu, vd
  `c` → `c.withValues(alpha: 0.85)`) thay vì `color: c` phẳng.
- Thêm entrance pop-in nhẹ (scale từ 0.8→1.0, ~200ms, `Curves.easeOutBack`)
  khi ribbon mount, tôn trọng `NeonTheme.reducedMotion`.

## Acceptance criteria
- [ ] Ribbon có gradient thay vì màu phẳng.
- [ ] Ribbon có entrance animation, tắt đúng khi `reducedMotion`.
- [ ] Test xác nhận không throw ở cả 2 trạng thái.

## Ghi chú độ tin cậy
Thấp — cải thiện thẩm mỹ chủ quan nhỏ, effort thấp, rủi ro thấp (widget
đơn giản, dùng ở nhiều nơi — `ShopItemCard` là nơi chính). Không khẩn cấp.
