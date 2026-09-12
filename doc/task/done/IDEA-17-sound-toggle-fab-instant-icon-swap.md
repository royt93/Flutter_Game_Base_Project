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
- [x] Đổi icon có crossfade/scale transition thay vì snap tức thời.
- [x] Tôn trọng `NeonTheme.reducedMotion`.
- [x] Test TDD xác nhận: tap đổi đúng icon cuối cùng, reducedMotion → duration = 0.
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — giá trị polish thật nhưng nhỏ, effort thấp nhất trong nhóm
finding này (chỉ cần bọc 1 `AnimatedSwitcher`, không cần logic mới). Dễ làm
nhanh nếu muốn 1 quick win.

## Quyết định
Đúng như đề xuất: bọc `Icon(...)` trong `AnimatedSwitcher` với
`key: ValueKey(muted)`, `duration` = `NeonTheme.reducedMotion(context) ?
Duration.zero : 150ms`, `transitionBuilder` kết hợp `ScaleTransition` +
`FadeTransition`.

Test cũ (`tap toggles muted and flips the icon`) phải đổi 2 chỗ `pump()`
sau tap thành `pumpAndSettle()` — với `AnimatedSwitcher` thật (duration >
0), 1 frame duy nhất sau tap không đủ để crossfade hoàn tất, 2 icon (cũ +
mới) cùng tồn tại giữa chừng, phá vỡ assertion `findsOneWidget` gốc. Thêm 2
test mới: 1 test xác nhận rõ ràng cả 2 icon cùng tồn tại giữa chừng frame
(bằng chứng crossfade có chạy thật), 1 test xác nhận reducedMotion → đổi
tức thời (duration = 0).

Test: 4 test (root, +2 so với trước). `flutter analyze` sạch. `flutter
test --exclude-tags slow`: root 472 passing, example 29 passing, không
regression.

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Buttons & Interactive → tap SoundToggleFab 2 lần (mute → unmute), icon
đổi đúng cả 2 chiều (volume_up ↔ volume_off) qua screenshot thật, không
exception trong logcat. Không capture được frame giữa crossfade (giới hạn
round-trip screenshot đã ghi nhận nhiều lần trong session này, 150ms <
round-trip latency) — bằng chứng chính là test đơn vị + end-state đúng
trên thiết bị thật.
