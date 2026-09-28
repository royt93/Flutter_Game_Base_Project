---
id: BUG-87
title: "deleteSlot xóa metadata trước data, failure làm mồ côi slot"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/save_slot_manager.dart:338` `deleteSlot`.

## Hiện trạng

Hàm remove slot khỏi `_slotList`, schedule persist metadata (340-341), rồi mới await `removeAllWithPrefix` (342). Throw giữa chừng để lại data mồ côi, metadata mất, active có thể trỏ slot không còn metadata.

## Vì sao cần / Hậu quả

Danh sách save slot và payload không còn nhất quán; user mất đường vào save cũ nhưng data vẫn chiếm storage.

## Đề xuất

Xóa slot data trước, metadata sau; active chỉ remove sau khi cả data + metadata commit xong. Cân nhắc rollback/cảnh báo crash-window vì không có transaction đa-key.

## Acceptance criteria

- [x] Test throw khi xóa data → metadata + active giữ nguyên.
- [x] Xóa thành công → prefix data, metadata, active (nếu trỏ slot) cùng biến mất.

## Quyết định

**Implementation:** Đảo thứ tự trong `deleteSlot` — `await
StorageService.to.removeAllWithPrefix('slot_${id}_')` chạy TRƯỚC
`_slotList.removeWhere`/`_scheduleSave`, và active chỉ bị `remove` sau khi
cả 2 bước trên hoàn tất. Nếu data-delete throw, metadata/activeSlotId hoàn
toàn không bị đụng tới — không còn cửa sổ "metadata mất nhưng data còn"
(mồ côi ngược) trước đây.

**Phát hiện phụ trong lúc TDD:** helper test `debugPendingSaves` (getter
`Future<void> get debugPendingSaves => _saveChain`) chỉ await snapshot
Future TẠI THỜI ĐIỂM GỌI — nếu một save khác được reschedule sau đó
(`_saveChain` bị gán lại) trong lúc đang await, test có thể đọc storage
trước khi save mới nhất thực sự ghi xong. Sửa thành vòng lặp
`while (_saving) await _saveChain;` để chờ đến khi hàng đợi save thực sự
rỗng, khớp đúng pattern `_saveDirty`-style ở nơi khác trong repo. Đây là
bug tiềm ẩn từ trước (không phải do BUG-87 fix trực tiếp gây ra) nhưng lộ
diện chỉ khi `deleteSlot` có thêm 1 await thật trước mutation — sửa cùng
lúc vì nếu không, test race hiện có (`Slice 3`) sẽ flaky.

**TDD:** 2 test mới trong `test/core/save_slot_manager_test.dart` (group
`BUG-87`) — dùng `_ThrowingPrefixDeleteStorage` (subclass override
`removeAllWithPrefix` để throw `StateError` giả lập): (1) throw giữa chừng
→ `listSlots()`/`activeSlotId` giữ nguyên, không mồ côi; (2) xoá thành công
→ data prefix + metadata + active cùng biến mất. Cũng sửa 1 test race hiện
có (`unawaited(deleteSlot(...))`) để await đúng Future của chính lệnh gọi
đó trước khi assert (deleteSlot nay có await thật trước mutation nên không
còn đồng bộ hoàn toàn tới điểm đó).

**Kết quả:** `flutter analyze` sạch root + `example/`. `flutter test
--exclude-tags slow` sạch root + `example/`, toàn bộ 38 test trong
`save_slot_manager_test.dart` pass (bao gồm Slice 1/2/3, ENH-68, ENH-72,
BUG-41, BUG-45, BUG-87 mới) — không regression.

**Tự chấm (v1):** 9/10. Fix đúng nguyên nhân gốc (thứ tự 2 side-effect không
transaction), phát hiện và sửa thêm 1 lỗ hổng race trong helper test
(`debugPendingSaves`) mà lẽ ra sẽ làm suite flaky ngầm về sau.

**Re-audit độc lập (fork riêng) phát hiện gap thật:** thứ tự data-trước-
metadata đúng, nhưng `_scheduleSave()` là fire-and-forget và `_runSave()`
tự nuốt mọi lỗi (`catch (_) {}`, có chủ đích để không làm kẹt hàng đợi save
của các call khác) — `deleteSlot` (v1) chỉ `await _waitForPendingSaves()`
rồi xoá `activeSlotId` NGAY, không hề biết save đó có thực sự ghi xuống
disk hay đã âm thầm thất bại. Một lỗi persist thật ở bước metadata sẽ bị
nuốt hoàn toàn, `deleteSlot` trả về như đã xong trong khi metadata cũ vẫn
còn nguyên trên disk.

**Fix v2 (rollback best-effort, theo lựa chọn người dùng):** `deleteSlot`
nay: (1) snapshot data qua `exportWithPrefix` TRƯỚC khi xoá; (2) xoá data;
(3) snapshot in-memory metadata + `wasActive` TRƯỚC khi mutate; (4) mutate,
`_scheduleSave()`, đợi hàng đợi rỗng; (5) đọc lại THẬT từ disk
(`_store.load()`) để xác nhận id đã thực sự biến mất — không tin tưởng
"await xong là chắc chắn thành công" nữa; (6) nếu vẫn còn trên disk (persist
thất bại): khôi phục data qua `importWithPrefix`, khôi phục `_slots` về
snapshot, `_scheduleSave()` lại, rồi `throw StateError` thay vì trả về như
đã xong; (7) chỉ xoá `activeSlotId` sau khi bước (5) xác nhận thành công
thật. Giới hạn đã biết (ghi trong code + đây): multi-key storage không có
transaction nguyên tử tuyệt đối — vẫn còn 1 cửa sổ rất hẹp giữa (2) và (6)
nếu process bị kill đúng lúc đó; "best effort" nghĩa là mọi lỗi runtime
(throw) được rollback, không phải mọi kịch bản process-kill.

**TDD bổ sung:** `_ThrowingMetaPersistStorage` (chỉ throw đúng lúc
`setString(saveSlotMetaV1, ...)`, để phân biệt "chưa từng persist" với
"removal thất bại") + 1 test mới: metadata persist throw sau khi data đã
xoá thành công → xác nhận data được khôi phục lại, metadata + activeSlotId
giữ nguyên, `deleteSlot` throw thay vì trả về êm.

**Widget test bổ sung (gap thật khác từ re-audit — trước đó KHÔNG có test '
nào cho nút xoá slot trong UI):** `example/test/save_cloud_screen_test.dart`
— 3 test mới: tap xoá 1 slot (happy path, không exception), xoá slot đang
active thì nút "+10 score" disable lại đúng, xoá 1 trong 2 slot thì slot
còn lại + score của nó không đổi.

**Integration/device test bổ sung:** `example/integration_test/app_boot_test.dart`
— test `BUG-87` tạo slot thật, set active, ghi data thật, xoá, xác nhận cả
3 (data/metadata/active) cùng biến mất trên SharedPreferences THẬT của
thiết bị (không phải mock).

**Tự chấm (v2, sau re-audit + fix):** 9.5/10. Điểm trừ còn lại: rollback
"best-effort" (đã nêu rõ), không phải transaction nguyên tử tuyệt đối qua
nhiều key — giới hạn vốn có của SharedPreferences, đã tài liệu hoá đầy đủ
thay vì giả vờ đã giải quyết triệt để.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify thứ tự `_slotList.removeWhere`/`_scheduleSave` trước `await removeAllWithPrefix` tại dòng 338-345.
