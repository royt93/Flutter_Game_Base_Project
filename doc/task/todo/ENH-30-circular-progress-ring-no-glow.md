---
id: ENH-30
title: "CircularProgressRing's arc vẽ phẳng, không glow — khác tông với ProgressBarStars cùng họ"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork C)
---

## Vị trí
`lib/presentation/widgets/common/circular_progress_ring.dart` —
`_RingPainter.paint()`:
```dart
final fillPaint = Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = strokeWidth
  ..strokeCap = StrokeCap.round;
final rect = Rect.fromCircle(center: center, radius: radius);
canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fillPaint);
```

## Hiện trạng
`ProgressBarStars` (cùng nhóm Progress & Reward, cùng mục đích "thanh tiến
trình") vẽ fill với `boxShadow: NeonTheme.glow(fill, blur: 10, spread: 0.5)`
— một viền sáng kẹo ngọt đặc trưng của cả kit. `CircularProgressRing` vẽ
arc bằng `Canvas.drawArc` thuần, không có glow nào — chỉ là 1 nét stroke
phẳng. 2 widget cùng vai trò (progress fill) nhưng khác hẳn về độ "premium".

## Vì sao cần
Người dùng yêu cầu rà soát UI/animation cho "xịn sò" hơn — đây là 1 điểm
không nhất quán rõ ràng và dễ sửa: cùng 1 khái niệm progress fill, 1 nơi có
glow candy-style, 1 nơi không.

## Đề xuất
Thêm 1 lớp `drawArc` thứ 2 mờ hơn/rộng hơn phía sau nét chính để giả lập
glow (`CustomPainter` không nhận `boxShadow` như `Container`, nhưng
`MaskFilter.blur` trên `Paint` tạo hiệu ứng glow tương tự):
```dart
final glowPaint = Paint()
  ..color = color.withValues(alpha: 0.5)
  ..style = PaintingStyle.stroke
  ..strokeWidth = strokeWidth + 6
  ..strokeCap = StrokeCap.round
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, glowPaint);
canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fillPaint); // nét chính vẽ sau, đè lên glow
```

## Acceptance criteria
- [ ] `CircularProgressRing`'s arc có glow nhất quán với `ProgressBarStars`.
- [ ] Golden test hoặc widget test xác nhận painter vẽ thêm lớp glow khi `progress > 0`.
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.
