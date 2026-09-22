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
- [x] Sau `applyRestore` thành công, `SaveSlotManager.listSlots()` trả về đúng slot vừa restore (đúng id/tên/timestamp từ `RestorePreview`).
- [x] Nếu 1 slot trong preview thất bại giữa chừng, các slot đã restore trước đó (kể cả metadata) vẫn giữ nguyên; slot lỗi không thêm metadata mồ côi.
- [x] Restore 1 slot đã tồn tại sẵn trong `listSlots()` (case backup/overwrite) không tạo entry trùng.
- [x] Test round-trip đầy đủ: export → xóa app state giả lập (rỗng `_metaStorageKey`) → `applyRestore` → `listSlots()` thấy đúng slot.

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

## Quyết định

Fix đúng như đề xuất — thêm `SaveSlotManager.restoreSlotMeta(SaveSlotMeta meta)` (idempotent: id đã tồn tại thì thay thế, chưa có thì thêm mới; KHÔNG bị chặn bởi `maxSlots` vì đây là khôi phục dữ liệu cũ chứ không phải tạo mới) và gọi nó ngay sau `importWithPrefix` thành công trong `applyRestore` — trước khi ghi `recoveryLog`, nên nếu `restoreSlotMeta` tự nó throw (không nên xảy ra, nhưng nếu có) vẫn rơi đúng vào nhánh `catch` hiện có, không để lại state nửa vời.

**Bài học khi viết test (đáng ghi lại)**: `SaveSlotManager` không nhận `StorageService` qua constructor — nó luôn đọc/ghi qua `StorageService.to` (GetX singleton). Test lúc đầu tạo "2 `SaveSlotManager` độc lập" (1 cái `slotManager` gốc, 1 `freshManager` mới) để mô phỏng "thiết bị mất state" — SAI, vì cả 2 instance đọc CHUNG đúng 1 `StorageService.to` đã đăng ký 1 lần trong test, nên "`freshManager` rỗng" không có thật (nó thấy y hệt dữ liệu `slotManager` đã ghi). Sửa lại bằng cách gọi `slotManager.deleteSlot(id)` thật (xóa cả data lẫn metadata) trước khi `applyRestore` — tạo đúng trạng thái "chưa từng biết slot này" trên CÙNG 1 manager, đúng bản chất kịch bản thật hơn (khôi phục 1 slot đã lỡ xóa/mất, không phải giả lập đa-thiết-bị trong 1 process test).

**TDD:** viết trước, `git stash` riêng 2 file lib — 2/3 test fail đúng (test round-trip: `listSlots()` rỗng thay vì có 1 slot; test crash-giữa-chừng: A không có mặt trong `listSlots()` sau restore đáng lẽ phải có). Test thứ 3 (restore đè lên slot đã tồn tại) pass cả 2 code cũ/mới — hợp lý vì code cũ vốn không XÓA metadata, chỉ không THÊM MỚI khi thiếu, nên case "đã tồn tại sẵn" không tự phân biệt được (đã ghi rõ, không giấu). Khôi phục fix: cả 3 pass, không phá test cũ nào trong `save_slot_manager_test.dart`/`disaster_recovery_save_export_test.dart`.

**Không phá gì:** `flutter analyze` root sạch. `dart run tool/api_compatibility.dart check` → unchanged (thêm 1 public method, không đổi/xóa export nào). `flutter test --exclude-tags slow` root: 2048 pass / 19 fail (đúng 19 golden có sẵn, không tăng).

Không cần smoke test device — fix nội bộ tầng service thuần, dùng qua `Get.put` không đổi hành vi observable bên ngoài luồng disaster-recovery (chưa có UI thật gọi `applyRestore` trong `example/`).

**Tự chấm điểm: 9.5/10.** Fix đúng root cause, xử lý đúng cả case idempotent (overwrite) lẫn case thất bại giữa chừng (không mồ côi lỗi), phát hiện + sửa 1 lỗi thiết kế test thật (giả định sai về `StorageService.to` là per-instance) trước khi commit thay vì để lại test sai lặng lẽ pass nhầm lý do.
