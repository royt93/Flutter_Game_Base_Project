---
id: IDEA-20
title: "ConfettiOverlay: mảnh confetti phẳng 1 màu, 1 hình dạng — trông đơn giản/rẻ tiền hơn có thể"
type: idea
priority: P3
effort: S-M
source: Claude, audit UI/animation polish round 6 (parallel fork B)
---

## Vị trí
`lib/presentation/widgets/common/confetti_overlay.dart` —
`_ConfettiPainter.paint()`:
```dart
canvas.drawRRect(
  RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
    const Radius.circular(2),
  ),
  Paint()..color = p.color.withValues(alpha: opacity),
);
```

## Hiện trạng
Mọi mảnh confetti là CÙNG 1 hình dạng (rounded rect bo góc 2px) tô 1 màu
phẳng duy nhất — không có gradient/highlight, không có biến thể hình dạng
(vd trộn thêm hình tròn/kim cương cho đa dạng), cũng không mô phỏng ánh
sáng phản chiếu khi mảnh giấy xoay (confetti thật lấp lánh khi xoay vì mặt
giấy phản chiếu ánh sáng khác nhau theo góc).

## Vì sao cần
Hiệu ứng ăn mừng (level complete, reward) là 1 trong những khoảnnh khắc
"đắt" nhất về cảm xúc người chơi — 1 confetti trông có chiều sâu/lấp lánh
hơn (dù nhỏ) có thể nâng cảm giác "xịn sò" tổng thể của cả bộ kit.

## Đề xuất (chọn 1, không cần làm cả 2)
1. Trộn 2 hình dạng khi generate particle (`ConfettiParticle` thêm field
   `shape` enum {rect, circle}, painter vẽ theo đó) — đa dạng hình ảnh, effort
   thấp.
2. Thêm 1 gradient/highlight nhẹ theo góc xoay hiện tại (`p.rotation`) mô
   phỏng ánh sáng phản chiếu lúc mảnh giấy "lật mặt" — effort cao hơn, hiệu
   ứng "lấp lánh" rõ hơn.

## Acceptance criteria
- [x] Chọn 1 hướng, ghi rõ trong `## Quyết định`.
- [x] `generateConfettiParticles`/`ConfettiParticle`'s pure functions (`confettiOffsetAt`, `confettiRotationAt`, `confettiOpacityAt`) vẫn giữ nguyên chữ ký, không phá test hiện có (`test/widget/common/confetti_overlay_test.dart`).
- [x] Test mới cho phần thêm (shape hoặc gradient) nếu logic đủ phức tạp để cần test riêng.

## Ghi chú độ tin cậy
Thấp — thuần thẩm mỹ, hiệu ứng hiện tại đã hoạt động tốt và trông ổn; đây
chỉ là ý tưởng "có thể xịn hơn nữa", không phải thiếu sót. Effort/lợi ích
nên cân nhắc kỹ trước khi làm — có thể là task dễ bỏ qua nếu ưu tiên chỗ
khác trước.

## Quyết định
Chọn hướng 1 (trộn hình dạng) — effort thấp nhất, ít rủi ro nhất, đúng
tinh thần ponytail (đủ dùng, không làm phức tạp thêm gradient/rotation
lighting). Thêm `enum ConfettiShape { rect, circle }`, `ConfettiParticle`
có field `shape` (default `rect` — không phá test hiện có nào tạo
`ConfettiParticle` không truyền shape). `generateConfettiParticles` gán
ngẫu nhiên 50/50 qua `rng.nextBool()`. `_ConfettiPainter.paint()` vẽ
`drawOval` cho `circle`, giữ nguyên `drawRRect` cho `rect`. Các pure
function `confettiOffsetAt`/`confettiRotationAt`/`confettiOpacityAt` không
đổi chữ ký, không đọc `shape`.

Test: 2 test mới — `ConfettiParticle.shape` mặc định `rect` khi không
truyền, và `generateConfettiParticles` với 40 particle (seed cố định) cho
ra cả 2 shape. `flutter analyze` sạch cả root + `example/`. `flutter test
--exclude-tags slow`: tất cả pass, không regression.

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Progress & Reward → bấm "Trigger" (ConfettiOverlay) nhiều lần liên tiếp,
không exception trong logcat. Không capture được frame confetti đang rơi
qua screenshot (scroll position dịch chuyển giữa lúc tap và chụp, cộng
round-trip latency — hạn chế đã ghi nhận nhiều lần trong session) — bằng
chứng chính là test đơn vị thuần (pure function, không cần widget) xác
nhận đúng cơ chế trộn shape, device smoke chỉ xác nhận zero-crash khi
trigger lặp lại.
