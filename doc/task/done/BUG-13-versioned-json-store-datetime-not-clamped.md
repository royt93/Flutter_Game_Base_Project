---
id: BUG-13
title: "VersionedJsonStore.save() stamp syncedAtMs bằng DateTime.now(), không qua ClampedClock"
type: bug
priority: P1
effort: S
verified: true
source: Claude, audit round 2 (fork agent), verify lại code thật
---

## Vị trí
`lib/core/versioned_json_store.dart:44` — `save()` stamp `syncedAtMs` bằng
`DateTime.now().millisecondsSinceEpoch` trực tiếp, không qua `nowMsClamped()`
(`lib/core/utils/clamped_clock.dart`).

## Hậu quả
`syncedAtMs` là timestamp dùng cho last-write-wins khi `syncWith()` merge với
cloud save. Toàn bộ phần còn lại của package (energy, daily login, offline
progression, review cooldown) đều cố ý dùng `nowMsClamped()` cho đúng 1 lý do:
chống tua đồng hồ máy. Đây là chỗ DUY NHẤT trong `lib/core/` còn dùng
`DateTime.now()` trực tiếp cho 1 giá trị ảnh hưởng tới reward/save-state —
đúng lớp lỗi mà toàn bộ package được thiết kế để tránh (xem README "Cheat-proof
offline earnings"). Người chơi tua đồng hồ máy trước khi sync có thể làm save
cũ (local) thắng nhầm save mới (cloud) hoặc ngược lại.

## Đề xuất fix
Đổi `DateTime.now().millisecondsSinceEpoch` thành `nowMsClamped()` trong
`save()`. Thêm test xác nhận `syncedAtMs` không lùi lại được dù device clock
bị chỉnh lùi giữa 2 lần `save()`.

## Acceptance criteria
- [ ] `save()` dùng `nowMsClamped()` cho `syncedAtMs`.
- [ ] Test: tua đồng hồ máy lùi giữa 2 lần `save()`, `syncedAtMs` lần sau vẫn
      >= lần trước.
