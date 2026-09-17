---
id: ENH-72
title: "SaveSlotManager: thiếu getter kiểm tra 'còn tạo được slot mới không' trước khi gọi createSlot"
type: enhancement
priority: low
effort: XS
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/save_slot_manager.dart`)
---

## Vị trí
Mở rộng — `lib/core/save_slot_manager.dart` (`SaveSlotManager`).

## Hiện trạng
ENH-68 (đã done) thêm `maxSlots` (nullable — `null` nghĩa là không giới hạn) và làm `createSlot` throw `StateError` khi đã đạt giới hạn. Nhưng KHÔNG có getter nào để 1 UI kiểm tra TRƯỚC khi gọi `createSlot` xem có nên disable nút "Create slot" hay không. Xác nhận qua đọc toàn bộ class: chỉ có field `maxSlots` (nullable) và `listSlots()` — không có `canCreateSlot`/`isAtMaxSlots`/`remainingSlots` nào. 1 consumer muốn disable nút phải tự viết `saveSlots.maxSlots == null || saveSlots.listSlots().length < saveSlots.maxSlots!` — vướng phải xử lý `null` thủ công, dễ viết sai (ví dụ quên check `null`, vô tình luôn coi là đã đầy).

## Vì sao cần / Hậu quả
Đây đúng loại "expose derived state qua getter thay vì bắt caller tự tính lại" mà nhiều task khác trong package này đã làm (`SeasonEventWindow.isActive`, `AchievementService.progressOf`/`thresholdOf`) — giờ `SaveSlotManager` lại là chỗ thiếu chính pattern đó, ngay trong chính field `maxSlots` nó vừa thêm (ENH-68). Ví dụ demo `widget_showcase_screen.dart` hiện tại: nút "Create slot" luôn bật (không có giới hạn được set trong demo) — nếu 1 consumer THẬT có set `maxSlots`, họ phải tự viết logic disable nút, dễ quên check `null` và tự bug.

## Đề xuất
Thêm 1 getter thuần, đọc-only, không đổi hành vi `createSlot`/`maxSlots` hiện có:

```dart
/// `true` if [createSlot] can be called right now without throwing —
/// always `true` when [maxSlots] is `null` (unlimited).
bool get canCreateSlot => maxSlots == null || listSlots().length < maxSlots!;
```

Không đổi `createSlot`'s `StateError` hiện có (giữ nguyên — `canCreateSlot` chỉ là tiện ích kiểm tra trước, không thay thế validate bên trong `createSlot`).

## Acceptance criteria
- [x] `canCreateSlot` trả về `true` khi `maxSlots == null` (không giới hạn), bất kể đã có bao nhiêu slot.
- [x] `canCreateSlot` trả về `true` khi số slot hiện có `< maxSlots`, `false` khi đã bằng `maxSlots`.
- [x] Sau khi `deleteSlot` làm số slot giảm xuống dưới `maxSlots`, `canCreateSlot` trở về `true` đúng.
- [x] Không đổi hành vi `createSlot`/`maxSlots`/bất kỳ method nào khác; không phá test cũ trong `test/core/save_slot_manager_test.dart`.
- [x] Test: unit test đầy đủ mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-72-save-slot-manager-can-create-slot-getter.md` này trước khi làm. Đọc `lib/core/save_slot_manager.dart` toàn bộ (đặc biệt `maxSlots`/`createSlot`/`listSlots` từ ENH-68) trước khi thêm getter. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với pattern các getter khác trong repo, không phá API/test hiện có, không over-engineer — đúng 1 getter thuần, không thêm gì khác).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/` (nếu muốn minh hoạ, cân nhắc set `maxSlots` cho demo `SaveSlotManager` sẵn có trong `widget_showcase_screen.dart` và disable nút "Create slot" qua `canCreateSlot` — không bắt buộc, nếu làm phải test + device smoke test).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `save_slot_manager.dart`: `maxSlots` (nullable) và `listSlots()` tồn tại, nhưng không có bất kỳ getter nào tên `canCreateSlot`/`isAtMaxSlots`/`remainingSlots`. Đã kiểm tra hướng khác liên quan (liệu `SaveSlotManager.deleteSlot` có dọn đúng key của các service vừa nhận `storageKey` ở ENH-71 hay không) — xác nhận KHÔNG PHẢI gap: `deleteSlot` gọi `StorageService.removeAllWithPrefix('slot_${id}_')` hoạt động ở tầng key-value thô của `StorageService`, nên tự động quét đúng MỌI key có prefix đó bất kể key đó thuộc `VersionedJsonStore` của service nào (kể cả các service dùng `keyFor` từ ENH-71) — không cần sửa gì thêm ở đó. Effort cực nhỏ (1 getter thuần), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Thêm đúng 1 getter thuần như đề xuất — `maxSlots == null || _slotList.length < maxSlots!`. Dùng `_slotList` (danh sách nội bộ chưa sort) thay vì `listSlots()` (có sort + copy) cho việc đếm số lượng — chỉ cần `.length`, không cần thứ tự, tránh 1 phép sort/copy thừa mỗi lần gọi getter.

**Test:** 4 test mới trong `test/core/save_slot_manager_test.dart` nhóm "ENH-72" — `maxSlots == null` luôn `true`, đúng ngưỡng `true`/`false` khi so với `maxSlots`, trở về `true` sau `deleteSlot`, và khớp đúng với việc `createSlot` có throw `StateError` hay không (test tích hợp xác nhận `canCreateSlot` không chỉ đúng lý thuyết mà đúng THỰC TẾ so với hành vi `createSlot`).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1234/1234 pass. Không đụng `example/` (không bắt buộc, demo hiện tại không set `maxSlots` nên không có gì để minh hoạ thêm có ý nghĩa).

**Tự chấm điểm: 10/10** — đúng 1 getter thuần, đúng pattern "expose derived state" đã dùng nhất quán trong repo, tối ưu nhỏ hợp lý (dùng `_slotList` thay vì `listSlots()`), test bao phủ đủ và có 1 test tích hợp xác nhận đúng khớp với `createSlot` thật.
