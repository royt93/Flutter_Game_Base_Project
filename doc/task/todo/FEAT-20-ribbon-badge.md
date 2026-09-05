---
id: FEAT-20
title: RibbonBadge/CornerRibbon — nhãn chéo góc "NEW"/"SALE"/"BEST VALUE"
type: feature
priority: P2
effort: S
source: user pick (đã chốt trong phiên chọn widget mới)
---

## Vì sao cần
Nhãn chéo góc cho item shop/gói IAP (đi cùng FEAT-01) — chưa có trong bộ 21
widget `common/` hiện tại.

## Đề xuất phạm vi
`RibbonBadge`: widget bọc ngoài 1 `child` bất kỳ (giống cách `IconBadgeButton`
bọc icon), vẽ dải ruy băng chéo góc trên cùng với text + màu tuỳ chỉnh
(mặc định theo `NeonTheme` palette), dùng `Positioned`/`Transform.rotate` bên
trong `Stack` riêng của chính widget (không phụ thuộc `Stack` của caller —
tránh lặp lại vấn đề của `LoadingOverlay`, xem ENH-03).

## Yêu cầu test
- **Unit test**: không cần (widget thuần trình bày, không có logic tính toán tách biệt được).
- **Widget test**: dựng `RibbonBadge` bọc 1 `child` mẫu, golden test cho vài biến thể màu/text (theo đúng convention `test/widget/goldens/` đã có).
- **Integration test**: dựng 1 `PanelCard`/shop-item mẫu có `RibbonBadge` trong `example/integration_test/`, verify hiển thị đúng không lỗi layout trên thiết bị thật.

## Demo
Thêm ví dụ `RibbonBadge` bọc quanh 1 `PanelCard` mẫu trong `WidgetShowcaseScreen`.

## Acceptance criteria
- [ ] Widget tự chứa `Stack` riêng, dùng được ở bất kỳ đâu không cần ancestor `Stack` từ caller.
- [ ] Đủ 3 loại test (widget test có golden) + demo trong showcase.
