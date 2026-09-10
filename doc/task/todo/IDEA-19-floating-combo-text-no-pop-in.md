---
id: IDEA-19
title: "FloatingComboText thiếu 'pop' scale lúc xuất hiện — chỉ rise+fade, thiếu juice so với RewardPopup"
type: idea
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork B)
---

## Vị trí
`lib/presentation/widgets/common/floating_combo_text.dart` —
`_FloatingComboTextState.build()`:
```dart
return AnimatedBuilder(
  animation: _controller,
  builder: (context, child) => Transform.translate(
    offset: Offset(0, _rise.value),
    child: Opacity(opacity: _opacity.value, child: child),
  ),
  ...
```

## Hiện trạng
Text xuất hiện ở kích thước 100% ngay lập tức rồi trôi lên + mờ dần — không
có bước "pop" (scale từ nhỏ hơn 1 vọt lên 1, overshoot nhẹ) lúc spawn. Các
widget "khoảnh khắc ăn mừng" khác trong kit đều có bước pop-in kiểu này:
`RewardPopup`'s entrance `TweenAnimationBuilder` (`Curves.easeOutBack`,
scale 0.85→1), `NeonDialog`'s panel entrance tương tự. `FloatingComboText`
— dùng cho combo/score text như "+10", "Combo x3" — là ứng viên rất hợp để
thêm juice này vì bản chất là hiệu ứng ăn mừng ngắn, nhanh.

## Vì sao cần
Đúng tinh thần "animation xịn sò hơn": 1 bước scale pop-in rẻ (không cần
Tween/Curve mới, chỉ thêm 1 `Animation<double>` nữa từ `_controller` đã
có sẵn) có thể nâng đáng kể cảm giác "juicy" của combo text — hiệu ứng dùng
NHIỀU lần liên tiếp (demo "Spam combo x5") nên cải thiện nhỏ ở đây nhân lên
rõ rệt.

## Đề xuất
Thêm `_scale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Interval(0.0, 0.3, curve: Curves.easeOutBack)))`
(pop nhanh trong 30% đầu animation, phần còn lại giữ nguyên rise+fade hiện
tại) — bọc thêm `Transform.scale(scale: _scale.value, ...)` trong builder.

## Acceptance criteria
- [ ] `FloatingComboText` có scale pop-in ở đầu animation, không ảnh hưởng timing rise/fade hiện tại.
- [ ] `reducedMotion` vẫn hoạt động đúng (duration đã collapse về 0 theo code hiện tại — scale mới cũng phải tôn trọng điều đó, không snap về giá trị scale giữa chừng).
- [ ] Test mới xác nhận scale bắt đầu < 1 và kết thúc = 1.

## Ghi chú độ tin cậy
Thấp-trung bình — thuần thẩm mỹ ("would look better"), không sửa bug, hiệu
ứng hiện tại vẫn hoạt động tốt. Cân nhắc theo mức độ ưu tiên polish của dự
án.
