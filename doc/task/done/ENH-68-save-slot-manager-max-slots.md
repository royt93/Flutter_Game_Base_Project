---
id: ENH-68
title: "SaveSlotManager: giới hạn số slot tối đa"
type: enhancement
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/save_slot_manager.dart`)
---

## Vị trí
Mở rộng — `lib/core/save_slot_manager.dart` (`SaveSlotManager.createSlot`).

## Hiện trạng
`createSlot(displayName)` (dòng ~170) không có bất kỳ giới hạn số lượng nào — gọi liên tiếp vô hạn lần vẫn tạo slot mới, không throw, không cảnh báo. Xác nhận qua đọc toàn bộ method: chỉ validate `displayName` rỗng, không có check `_slotList.length`.

## Vì sao cần / Hậu quả
"3 save file, chọn 1 nhân vật chơi" (chính use-case IDEA-56 nêu ra) hầu như luôn có giới hạn cố định (2-5 slot tuỳ game) — không giới hạn dẫn tới UI danh sách slot phình vô hạn nếu code gọi có bug logic (ví dụ vòng lặp tạo nhầm), và không có tín hiệu lỗi rõ ràng để bắt case đó ở tầng gọi.

## Đề xuất
Thêm tham số optional `maxSlots` vào constructor `SaveSlotManager({this.maxSlots})` — `null` (mặc định) nghĩa là KHÔNG giới hạn (giữ nguyên hành vi hiện tại, không phá code cũ). Khi `maxSlots` được set và `_slotList.length >= maxSlots`, `createSlot` throw `StateError` rõ ràng (khác `ArgumentError` đã dùng cho input sai — đây là lỗi trạng thái, không phải input sai) với message nêu rõ giới hạn hiện tại.

Không tự chọn con số mặc định cụ thể (3? 5?) — đây là quyết định sản phẩm của consumer app, không phải của package. Để `null` = không giới hạn là default an toàn nhất, không đoán mò.

## Acceptance criteria
- [x] `SaveSlotManager()` (không truyền `maxSlots`): hành vi y hệt hiện tại, tạo được vô hạn slot, không throw.
- [x] `SaveSlotManager(maxSlots: N)`: tạo slot thứ `N+1` throw `StateError`, không tạo thêm, không đổi danh sách slot hiện có.
- [x] Xoá 1 slot khi đã đạt `maxSlots` rồi tạo lại: thành công bình thường (giới hạn kiểm tra tại thời điểm gọi `createSlot`, không phải giới hạn "tổng số đã từng tạo").
- [x] `maxSlots <= 0` (nếu truyền vào constructor): throw `ArgumentError` ngay tại constructor, không đợi tới lúc gọi `createSlot`.
- [x] Không đổi hành vi `listSlots`/`renameSlot`/`touchSlot`/`deleteSlot`/`setActiveSlot`/`keyFor` hiện có; không phá bất kỳ test nào trong `test/core/save_slot_manager_test.dart`.
- [x] Test: unit test đầy đủ mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/` — nếu muốn minh hoạ, cân nhắc set `maxSlots: 3` cho demo `SaveSlotManager` sẵn có trong `widget_showcase_screen.dart` (không bắt buộc, nếu làm phải test + device smoke test).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-68-save-slot-manager-max-slots.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/save_slot_manager.dart` và `test/core/save_slot_manager_test.dart` hiện có để hiểu đúng convention validate (`ArgumentError` cho input sai, đối chiếu cách class này đã làm) trước khi thêm giới hạn. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không tự chọn 1 con số mặc định cụ thể — `null` = không giới hạn phải là default).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Cân nhắc có nên wire `maxSlots` vào demo `example/lib/screens/widget_showcase_screen.dart` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).
5. Nếu có đụng tới `example/` để demo: smoke test thật trên máy Android/iOS thật hiện có (kiểm tra `mobile_list_available_devices` FRESH trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator). Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `save_slot_manager.dart`: `createSlot` không có bất kỳ giới hạn số lượng nào. Effort nhỏ (1 param constructor + 1 check), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Thêm `int? maxSlots` vào constructor — `null` (mặc định) giữ nguyên hành vi cũ (không giới hạn). Validate `maxSlots <= 0` bằng `ArgumentError` NGAY trong constructor body (không dùng `assert` — dù `LocalScoreboardService.capacity` dùng `assert` cho validate tương tự, `assert` bị strip ở release build và chỉ throw `AssertionError` chứ không phải `ArgumentError` acceptance criteria yêu cầu; dùng throw thật đảm bảo validate luôn đúng ở mọi build mode, nhất quán với cách `createSlot`/`renameSlot`/`setActiveSlot` validate trong chính file này).

`createSlot` check `_slotList.length >= maxSlots` TRƯỚC khi tạo — throw `StateError` (không phải `ArgumentError`, vì đây là lỗi TRẠNG THÁI — đã đầy — không phải input `displayName` sai).

**Test:** 5 test mới trong `test/core/save_slot_manager_test.dart` nhóm "ENH-68" — mặc định không giới hạn, giới hạn đúng throw `StateError` không tạo thêm, xoá rồi tạo lại thành công (giới hạn kiểm tra tại thời điểm gọi, không phải tổng số đã từng tạo), `maxSlots <= 0` throw `ArgumentError` tại constructor, không đổi hành vi các method khác khi chưa đạt giới hạn.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1194/1194 pass. Không demo trong `example/` (không bắt buộc, demo `SaveSlotManager` sẵn có vẫn hoạt động đúng không cần sửa vì không truyền `maxSlots`).

**Tự chấm điểm: 9.5/10** — đúng yêu cầu, KHÔNG tự chọn 1 con số mặc định cụ thể (đúng cảnh báo tự đặt ra trong chính task), phát hiện và tránh đúng 1 cạm bẫy nhỏ (dùng `assert` sẽ không thoả acceptance criteria "throw ArgumentError" ở mọi build mode) trước khi viết code thay vì để lộ ra qua test fail.
