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
- [x] Ribbon có gradient thay vì màu phẳng.
- [x] Ribbon có entrance animation, tắt đúng khi `reducedMotion`.
- [x] Test xác nhận không throw ở cả 2 trạng thái.

## Ghi chú độ tin cậy
Thấp — cải thiện thẩm mỹ chủ quan nhỏ, effort thấp, rủi ro thấp (widget
đơn giản, dùng ở nhiều nơi — `ShopItemCard` là nơi chính). Không khẩn cấp.

## Quyết định
Làm đúng cả 2 đề xuất: `RibbonBadge` chuyển từ `StatelessWidget` sang
`StatefulWidget` (`SingleTickerProviderStateMixin`) — dải ruy băng giờ vẽ
`BoxDecoration(gradient: LinearGradient(colors: [c, c.withValues(alpha:
0.85)]))` thay vì `color: c` phẳng, và bọc trong `Transform.scale` (0.8→
1.0, `Curves.easeOutBack`, 200ms) chạy 1 lần lúc mount qua
`AnimationController`.

Lưu ý kỹ thuật quan trọng: lúc đầu đọc `NeonTheme.reducedMotion(context)`
ngay trong `initState()` để set `duration`, nhưng phát hiện qua
`ConfettiOverlay` (đã có sẵn comment cảnh báo "MediaQuery không đọc được
trong initState") rằng đây là anti-pattern đã biết trong codebase này —
sửa lại đúng convention: đọc trong `didChangeDependencies()` (chạy 1 lần
trước build đầu tiên, dùng cờ `_startedOnce` để không lặp lại), set
`_controller.value = 1.0` trực tiếp nếu `reducedMotion` thay vì chạy
`forward()` với `duration: Duration.zero`.

Test mới (`test/widget/common/ribbon_badge_test.dart`, 3 test): đọc scale
qua `Transform.scale`'s `key: Key('ribbonBadgeScale')` (không dùng
`find.descendant` + `.last` mơ hồ, vì `Transform.rotate` bọc ngoài cũng là
1 `Transform` — dễ nhầm lẫn ma trận xoay với ma trận scale). Test xác nhận
pop-in (scale < 1 lúc mount → 1.0 khi settle), gradient có ≥2 màu, và
reducedMotion → scale = 1.0 ngay.

Golden test (`ribbon_badge_golden_test.dart`, `shop_item_card_golden_test.dart`
phần "with ribbon") đổi `await tester.pump()` → `await
tester.pumpAndSettle()` để chụp đúng trạng thái đã settle (không phải giữa
chừng pop) — golden ảnh regenerate qua `--update-goldens`.

Test: 3 test mới + 4 golden ảnh cập nhật. `flutter analyze` sạch cả root +
`example/`. `flutter test --exclude-tags slow`: tất cả pass, không
regression.

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Shop → RibbonBadge demo, gradient chéo trên ribbon "SALE"/"NEW" thấy rõ
qua screenshot (không còn màu phẳng đơn sắc), không exception trong
logcat. Không capture được frame giữa pop-in (200ms < round-trip latency,
giới hạn đã ghi nhận nhiều lần trong session) — bằng chứng chính là test
đơn vị xác nhận đúng scale range, device smoke xác nhận end-state đúng +
zero-crash.
