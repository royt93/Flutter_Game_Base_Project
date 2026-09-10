---
id: IDEA-17
title: "SoundToggleFab đổi icon volume_up/volume_off tức thời, không crossfade"
type: idea
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork A)
---

## Vị trí
`lib/presentation/widgets/common/sound_toggle_fab.dart` — bên trong
`Obx(() {...})`, `Icon(muted ? Icons.volume_off_rounded :
Icons.volume_up_rounded, ...)` đổi trực tiếp theo `muted`, không bọc trong
bất kỳ animated widget nào.

## Hiện trạng
Bấm nút mute/unmute đổi icon ngay lập tức trong 1 frame — không có
crossfade/scale transition giữa 2 icon. `PressableScale` vẫn cho cảm giác
bấm (scale khi nhấn), nhưng phần "kết quả" của hành động (icon đổi) hoàn
toàn tĩnh.

## Vì sao cần
Đây là nút bấm khá thường dùng (mute nhạc nền), 1 crossfade/scale-swap nhỏ
giữa 2 icon sẽ làm hành động cảm thấy được "xác nhận" rõ ràng hơn là chỉ
snap sang trạng thái mới.

## Đề xuất
Bọc `Icon(...)` trong `AnimatedSwitcher` (`duration` ngắn ~150ms,
`transitionBuilder` kiểu scale+fade) với `key: ValueKey(muted)` để
`AnimatedSwitcher` nhận diện đúng lúc cần chuyển. Tôn trọng
`NeonTheme.reducedMotion` — duration = 0 khi bật, icon vẫn đổi đúng, không
cần animation.

## Acceptance criteria
- [ ] Đổi icon có crossfade/scale transition thay vì snap tức thời.
- [ ] Tôn trọng `NeonTheme.reducedMotion`.
- [ ] Test TDD xác nhận: tap đổi đúng icon cuối cùng, reducedMotion → duration = 0.
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — giá trị polish thật nhưng nhỏ, effort thấp nhất trong nhóm
finding này (chỉ cần bọc 1 `AnimatedSwitcher`, không cần logic mới). Dễ làm
nhanh nếu muốn 1 quick win.
