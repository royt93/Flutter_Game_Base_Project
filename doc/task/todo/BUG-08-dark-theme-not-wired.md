---
id: BUG-08
title: Dark mode không có UI để bật/tắt, và không reactive khi đổi
type: bug
priority: P1
effort: M
verified: true
source: Claude (fork nội bộ) + agy, verify lại code thật
---

## Vị trí
- Đọc lúc boot: `example/lib/main.dart` (đọc `StorageKeys.themeDark` → set `NeonTheme.dark`)
- Thiếu ghi: `example/lib/screens/settings_screen.dart` — chỉ có locale picker +
  audio mute toggle (đã grep xác nhận, không có dòng nào set `themeDark`/`NeonTheme.dark`)
- `lib/core/neon_theme.dart:16` — `static bool dark = false;` là bool thường, không phải `RxBool`

## Vấn đề
2 lỗ hổng cộng dồn:
1. Không nơi nào trong `example/` cho phép người dùng bật dark mode — tính năng
   chỉ đọc được lúc boot, không ai ghi lại được, coi như chết.
2. Kể cả nếu code gọi thẳng `NeonTheme.dark = true`, các widget đang hiển thị
   sẽ KHÔNG tự rebuild vì đây là static field thường, không phải observable —
   cần gọi thủ công `Get.forceAppUpdate()` mà không nơi nào làm.

## Đề xuất fix — ĐÃ LÀM (xem code), cập nhật sau khi thử `Get.forceAppUpdate()`
Thêm `SwitchListTile` trong `SettingsScreen`, set `NeonTheme.dark` +
`StorageService.maybe?.setBool(StorageKeys.themeDark, v)`.

`Get.forceAppUpdate()` (đề xuất ban đầu) **KHÔNG dùng được** — verify bằng
test thật: nó gọi `engine.performReassemble()` (cơ chế hot-reload nặng, tự
ghi trong doc chính GetX "touch events will not work until end of
rendering"), gây vỡ assertion `schedulerPhase == SchedulerPhase.idle` khi gọi
giữa lúc đang xử lý tap trong test. Thay bằng: đổi `SettingsScreen` từ
`StatelessWidget` sang `StatefulWidget`, gọi `setState(() => NeonTheme.dark =
v)` cục bộ — nhẹ, an toàn, đủ để switch trên chính màn hình này cập nhật
ngay. Cân nhắc đổi `NeonTheme.dark` thành `RxBool` sau này nếu cần các màn
hình KHÁC đang mở cùng lúc cũng đổi màu ngay lập tức không cần điều hướng lại
(chưa làm ở fix này — ngoài phạm vi test đã viết).

## Acceptance criteria
- [ ] Có UI toggle dark mode trong `SettingsScreen`, persist qua restart.
- [ ] Toggle có hiệu lực ngay (không cần restart app) trên toàn bộ widget đang hiển thị.
