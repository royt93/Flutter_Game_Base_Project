---
id: ENH-33
title: "WheelSpinner's rim/pointer vẽ phẳng, không glow — khác tông candy của cả kit"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork C)
---

## Vị trí
`lib/presentation/widgets/common/wheel_spinner.dart` —
`WheelSpinnerPainter.paint()`'s rim stroke:
```dart
canvas.drawCircle(
  center,
  radius,
  Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..color = NeonTheme.ink,
);
```
và `Icon(Icons.arrow_drop_down_rounded, ...)` (pointer) trong `build()` —
cả 2 không có `boxShadow`/glow nào.

## Hiện trạng
`WheelSpinner` (widget mới nhất trong kit, thêm ở IDEA-13 cùng round này)
là widget "thưởng" (spin-to-win) duy nhất trong nhóm Progress & Reward
không dùng `NeonTheme.glow`/`drop` ở đâu cả — trong khi `RewardPopup`
(glow+drop trên panel), `ProgressBarStars` (glow trên fill),
`DailyLoginCalendarWidget`'s current-day slot (glow trên border) đều có.
Rim phẳng + pointer phẳng khiến bánh xe trông "thiếu sáng" so với phần còn
lại của kit.

## Vì sao cần
Đây là widget mới nhất, dễ chỉnh nhất (chỉ vừa viết, chưa có consumer nào
phụ thuộc hình dạng cụ thể), và là đúng loại "khoảnh khắc thưởng" mà kit
luôn dùng glow để nhấn mạnh.

## Đề xuất
Thêm `MaskFilter.blur` glow layer phía sau rim stroke (cùng kỹ thuật đề
xuất ở ENH-30 cho `CircularProgressRing`, dùng màu accent chính của bánh
xe — có thể lấy màu segment đang thắng hoặc 1 màu cố định như
`NeonTheme.gold`), và thêm `boxShadow: NeonTheme.glow(...)` cho pointer
`Icon` (dùng `shadows:` param của `Icon`, giống `StarRating`/
`ProgressBarStars`' marker).

## Acceptance criteria
- [x] Rim của `WheelSpinner` có glow, nhất quán với `RewardPopup`/`ProgressBarStars`.
- [x] Pointer icon có glow/shadow.
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Quyết định
Rim: thêm 1 `drawCircle` glow (stroke rộng 10px, màu gold alpha 0.5,
`MaskFilter.blur`) vẽ trước rim chính, cùng kỹ thuật ENH-30. Pointer: bọc
`Icon` trong `Container(decoration: BoxDecoration(shape: circle, boxShadow:
NeonTheme.glow(NeonTheme.gold, blur: 10)))` — dùng `boxShadow` được vì đây
là widget thường (`Container`), không phải canvas. Test: `painter.paint()`
qua `PictureRecorder` không throw + assert `Container` bọc pointer có
`boxShadow` non-null. Verify: `flutter analyze` sạch + `flutter test` 453
pass ở root, 29 pass ở `example/`. Device smoke Pixel 7 Pro thật: rim +
pointer đều có quầng vàng rõ ràng, đúng "candy" style.
