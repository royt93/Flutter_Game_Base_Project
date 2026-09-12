---
id: ENH-35
title: "ComboHeatBackground chỉ lerp màu phẳng (solid), không dùng gradient như phần còn lại của kit"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork D)
---

## Vị trí
`lib/presentation/widgets/common/combo_heat_background.dart` — `build()`:
```dart
final color = Color.lerp(cool, hot, heat.clamp(0.0, 1.0))!;
return AnimatedContainer(
  duration: ...,
  curve: Curves.easeOut,
  color: color,
  child: child,
);
```

## Hiện trạng
`AnimatedContainer.color` chỉ là 1 màu phẳng (solid), lerp tuyến tính giữa
`coolColor`/`hotColor`. Toàn bộ phần còn lại của kit (đặc biệt `NeonBg`,
"nền gradient candy sáng" + orb + sheen) dùng gradient dày đặc — 1 nền phản
ứng combo/heat chỉ đổi màu phẳng đọc "rẻ" hơn hẳn so với mood chung của
kit.

## Vì sao cần
`ComboHeatBackground` đóng vai trò nền phản ứng gameplay (combo/streak
nóng lên) — đây chính xác là loại hiệu ứng nên "cảm thấy" năng lượng tăng
dần, gradient toả từ tâm hoặc theo hướng sẽ truyền tải "heat" tốt hơn 1
màu phẳng đổi dần.

## Đề xuất
Đổi `color:` sang `decoration: BoxDecoration(gradient: RadialGradient(colors: [hot lerp ..., cool lerp ...]))`
(hoặc `LinearGradient` toả từ đáy lên, nơi input thường đến) —
`AnimatedContainer` hỗ trợ animate `decoration` (dùng
`DecoratedBoxTransition`-tương-đương ngầm qua `AnimatedContainer`, đã kiểm
tra `AnimatedContainer` animate `BoxDecoration` mượt mà không cần
`TweenAnimationBuilder` riêng). Giữ nguyên `coolColor`/`hotColor` API, chỉ
đổi cách render nội bộ.

## Acceptance criteria
- [x] Nền render bằng gradient thay vì màu phẳng, vẫn lerp mượt theo `heat`.
- [x] Test xác nhận decoration/gradient thay đổi đúng theo `heat` tại các mốc 0.0/0.5/1.0.
- [x] `NeonTheme.reducedMotion` vẫn hoạt động đúng (duration zero).

## Ghi chú độ tin cậy
Trung bình — cải thiện thẩm mỹ chủ quan, không phải bug. Cần xác nhận
`AnimatedContainer` animate `BoxDecoration` (gradient) mượt như animate
`color` trước khi làm — nếu không mượt bằng, có thể cần
`TweenAnimationBuilder<Color?>` riêng cho từng stop màu gradient.

## Quyết định
Xác nhận `AnimatedContainer` animate `decoration:` (BoxDecoration chứa
`LinearGradient`) mượt như animate `color:` — không cần
`TweenAnimationBuilder` riêng (nghi ngờ trong Ghi chú độ tin cậy không xảy
ra, `Gradient.lerp` nội bộ của Flutter xử lý đúng vì 2 decoration trước/sau
cùng runtimeType gradient, cùng số color stop). Đổi `color: color` thành
`decoration: BoxDecoration(gradient: LinearGradient(begin: topCenter, end:
bottomCenter, colors: [Color.lerp(color, Colors.white, 0.18)!, color]))` —
tái dùng ĐÚNG công thức gradient đã dùng ở `IconBadgeButton`/
`SoundToggleFab`/mọi button khác trong kit (lighter top, base color
bottom), thay vì phát minh công thức riêng — nhất quán với phần còn lại
của kit.

Test cũ đổi cách đọc từ `.color!` sang `.gradient!.colors.last` (phần tử
cuối của mảng `[lighter, color]` luôn chính là giá trị lerp(cool, hot,
heat) không pha trắng, nên assertion `expect(_renderedColor(tester),
_cool)` giữ nguyên không đổi). Thêm 1 test mới xác nhận gradient có ≥2 màu
khác nhau (không phải màu phẳng nguỵ trang thành gradient 1 màu).

Test: 1 test mới (root). `flutter analyze` sạch cả root + `example/`.
`flutter test --exclude-tags slow`: tất cả pass, không regression.

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Game Feel → bấm "Bump heat" 4 lần liên tiếp (0%→25%→...→100%), gradient
top-sáng/bottom-đậm hiện rõ qua screenshot ở mốc 25% và 100%, không
exception trong logcat.
