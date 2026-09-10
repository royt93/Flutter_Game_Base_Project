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
- [ ] Nền render bằng gradient thay vì màu phẳng, vẫn lerp mượt theo `heat`.
- [ ] Test xác nhận decoration/gradient thay đổi đúng theo `heat` tại các mốc 0.0/0.5/1.0.
- [ ] `NeonTheme.reducedMotion` vẫn hoạt động đúng (duration zero).

## Ghi chú độ tin cậy
Trung bình — cải thiện thẩm mỹ chủ quan, không phải bug. Cần xác nhận
`AnimatedContainer` animate `BoxDecoration` (gradient) mượt như animate
`color` trước khi làm — nếu không mượt bằng, có thể cần
`TweenAnimationBuilder<Color?>` riêng cho từng stop màu gradient.
