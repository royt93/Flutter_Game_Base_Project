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

## Đề xuất fix
- Thêm 1 `SwitchListTile`/`ToggleSwitch` trong `SettingsScreen` set
  `NeonTheme.dark` + `StorageService.to.setBool(StorageKeys.themeDark, v)` +
  `Get.forceAppUpdate()`.
- Cân nhắc đổi `NeonTheme.dark` thành `RxBool` hoặc tài liệu rõ nghĩa vụ gọi
  `forceAppUpdate()` sau khi đổi (đỡ phải sửa API công khai).

## Acceptance criteria
- [ ] Có UI toggle dark mode trong `SettingsScreen`, persist qua restart.
- [ ] Toggle có hiệu lực ngay (không cần restart app) trên toàn bộ widget đang hiển thị.
