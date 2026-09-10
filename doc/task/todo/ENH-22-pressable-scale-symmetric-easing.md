---
id: ENH-22
title: "PressableScale dùng chung 1 curve phẳng (easeOut) cho cả nhấn và thả — thiếu độ nảy khi thả tay"
type: enhance
priority: P2
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork A)
---

## Vị trí
`lib/presentation/widgets/pressable_scale.dart` — `_PressableScaleState.build()`:
```dart
child: AnimatedScale(
  scale: _down ? widget.scale : 1.0,
  duration: NeonTheme.reducedMotion(context)
      ? Duration.zero
      : const Duration(milliseconds: 90),
  curve: Curves.easeOut,
  child: widget.child,
),
```

## Hiện trạng
`PressableScale` là primitive dùng chung cho **toàn bộ** button/toggle
trong kit (`CommonButton`, `NeonButton`, `IconBadgeButton`,
`SoundToggleFab`, `CandyToggleSwitch`, `SegmentedTabBar`). Cả chiều nhấn
xuống (scale nhỏ lại) và chiều thả ra (scale về 1.0) đều dùng chung đúng 1
`curve: Curves.easeOut` + 90ms — chuyển động đối xứng, phẳng, không có bất
kỳ "nảy" (overshoot) nào khi thả tay ra. Vì đây là 1 file duy nhất được mọi
widget tương tác dùng chung, cảm giác bấm của TOÀN BỘ kit hiện đều phẳng
như nhau.

## Vì sao cần
1 nút bấm "candy"/"juicy" chuẩn mực (Duolingo, Candy Crush, ...) thường có
chiều thả tay nảy nhẹ quá 1.0 rồi mới ổn định (một chút overshoot), tạo
cảm giác đàn hồi/vật lý thay vì máy móc. Đây là điểm chạm phổ biến nhất
trong cả app (mọi lần bấm nút) nên polish ở đây có tác động cảm nhận rộng
nhất so với sửa từng widget riêng lẻ.

## Đề xuất
Tách 2 curve khác nhau cho 2 chiều: nhấn xuống giữ `Curves.easeOut` (nhanh,
dứt khoát), thả ra đổi sang 1 curve có overshoot nhẹ (`Curves.easeOutBack`
hoặc tương tự — đã dùng ở `RewardPopup`/`NeonDialog`'s entrance animation,
nhất quán với "ngôn ngữ chuyển động" đã có trong kit). Có thể cần
`AnimationController` riêng thay vì `AnimatedScale` nếu cần 2 curve khác
biệt rõ ràng theo hướng animation (down vs up), vì `AnimatedScale` chỉ nhận
1 curve áp dụng chung cho mọi lần đổi target value.

## Acceptance criteria
- [ ] Chiều thả tay có overshoot nhẹ, chiều nhấn xuống vẫn nhanh/dứt khoát.
- [ ] Vẫn tôn trọng `NeonTheme.reducedMotion` (duration = 0 cả 2 chiều khi bật).
- [ ] Test xác nhận: dưới reducedMotion, scale về đúng 1.0 ngay không cần chờ; khi không reducedMotion, thả tay có 1 frame scale > 1.0 (bằng chứng overshoot) trước khi settle về 1.0.
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test (cảm nhận trực tiếp độ nảy khi bấm 1 vài nút trong Widget Kit).

## Ghi chú độ tin cậy
Cao — đây là quan sát cụ thể từ code thật (1 curve duy nhất, đối xứng), và
"thiếu overshoot khi thả" là nhận định khách quan có thể verify bằng cách
đọc animation timeline, không chỉ là ý kiến thẩm mỹ chủ quan. Rủi ro duy
nhất là chọn giá trị overshoot/duration cụ thể (cần tinh chỉnh bằng mắt
trên thiết bị thật, không chỉ đọc code).
