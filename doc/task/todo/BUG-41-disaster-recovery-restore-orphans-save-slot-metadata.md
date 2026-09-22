---
id: BUG-41
title: "applyRestore() ghi lại đúng key của slot nhưng không đăng ký slot vào SaveSlotManager — slot mồ côi"
type: bug
priority: P1
effort: M
source: "codex + agy (độc lập xác nhận cùng 1 vấn đề), verify lại qua Read lib/core/disaster_recovery_save_export.dart:264-297 và lib/core/save_slot_manager.dart:54,176"
---

## Vị trí
`lib/core/disaster_recovery_save_export.dart` — `applyRestore(RestorePreview preview)` (dòng ~264-297); `lib/core/save_slot_manager.dart` — `_metaStorageKey = 'save_slot_meta_v1'` (dòng 54), `listSlots()` (dòng 176).

## Hiện trạng
`applyRestore` chỉ gọi `storage.importWithPrefix(slotManager.keyFor(entry.meta.id, ''), entry.data)` cho từng slot — ghi đúng các key `slot_<id>_*` lên storage. Nhưng `SaveSlotManager.listSlots()` đọc danh sách slot hiển thị từ 1 key metadata RIÊNG (`save_slot_meta_v1`), và `applyRestore` không hề cập nhật key này.

## Vì sao cần / Hậu quả
Sau khi restore thành công (`SdkSuccess`), dữ liệu thật đã nằm đúng trên disk, nhưng `listSlots()` không trả về slot đó — người chơi mở màn hình chọn slot vẫn thấy trống, tưởng nhầm restore thất bại dù dữ liệu đã có sẵn, không thể chọn/chơi tiếp slot vừa khôi phục.

## Đề xuất
Thêm phương thức `SaveSlotManager.restoreSlotMeta(SaveSlotMeta meta)` (ghi/merge `meta` vào danh sách `_metaStorageKey`, idempotent nếu slot đã tồn tại), gọi phương thức này trong `applyRestore` ngay sau khi `importWithPrefix` của slot đó thành công.

## Acceptance criteria
- [ ] Sau `applyRestore` thành công, `SaveSlotManager.listSlots()` trả về đúng slot vừa restore (đúng id/tên/timestamp từ `RestorePreview`).
- [ ] Nếu 1 slot trong preview thất bại giữa chừng, các slot đã restore trước đó (kể cả metadata) vẫn giữ nguyên; slot lỗi không thêm metadata mồ côi.
- [ ] Restore 1 slot đã tồn tại sẵn trong `listSlots()` (case backup/overwrite) không tạo entry trùng.
- [ ] Test round-trip đầy đủ: export → xóa app state giả lập (rỗng `_metaStorageKey`) → `applyRestore` → `listSlots()` thấy đúng slot.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-41-disaster-recovery-restore-orphans-save-slot-metadata.md` này trước khi làm. Đọc toàn bộ `lib/core/disaster_recovery_save_export.dart` và `lib/core/save_slot_manager.dart` (đặc biệt cấu trúc `SaveSlotMeta`, `_metaStorageKey`, `listSlots`/`createSlot`) trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (logic storage thuần, không có UI mới).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn độc lập (codex, agy) báo cùng 1 root cause; tự verify qua Read trực tiếp `applyRestore` (chỉ gọi `importWithPrefix`, không đụng `SaveSlotManager`) và xác nhận `listSlots` đọc key metadata riêng biệt. Không trùng task nào trong `doc/task/done/`.
