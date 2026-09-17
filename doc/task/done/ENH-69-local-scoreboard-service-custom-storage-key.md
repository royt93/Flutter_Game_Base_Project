---
id: ENH-69
title: "LocalScoreboardService: cho phép truyền storage key riêng — nối được với SaveSlotManager"
type: enhancement
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/local_scoreboard_service.dart` và `lib/core/save_slot_manager.dart`)
---

## Vị trí
Mở rộng — `lib/core/local_scoreboard_service.dart` (`LocalScoreboardService`).

## Hiện trạng
`LocalScoreboardService` dùng `static const _storageKey = 'local_scoreboard_v1'` (dòng 48) — HẰNG SỐ CỐ ĐỊNH, constructor (`LocalScoreboardService({this.capacity = 50})`) không có tham số nào để đổi key. Nghĩa là toàn bộ máy chỉ có ĐÚNG 1 bảng xếp hạng dùng chung, bất kể có bao nhiêu save slot (`SaveSlotManager`, IDEA-56, vừa thêm) đang tồn tại. 2 tính năng mới nhất trong repo (`SaveSlotManager`'s `keyFor(slotId, suffix)` và `LocalScoreboardService`) không nối được với nhau — không có cách nào có 1 bảng xếp hạng RIÊNG cho từng nhân vật/slot.

## Vì sao cần / Hậu quả
1 game nhiều nhân vật (dùng `SaveSlotManager`) muốn mỗi nhân vật có bảng xếp hạng cục bộ riêng (ví dụ leaderboard nội bộ theo từng save file, khác hẳn leaderboard toàn cục) không có cách làm nào ngoài việc tự fork lại toàn bộ logic `LocalScoreboardService` — lãng phí, dễ lệch hành vi so với bản gốc đã được test kỹ.

## Đề xuất
Thêm tham số optional `String? storageKey` vào constructor: `LocalScoreboardService({this.capacity = 50, String? storageKey}) : _storageKey = storageKey ?? 'local_scoreboard_v1'`. Mặc định `null` giữ NGUYÊN key cũ (`'local_scoreboard_v1'`) — không phá bất kỳ save nào đang tồn tại của consumer app hiện có. Một consumer muốn bảng riêng theo slot chỉ cần gọi `LocalScoreboardService(storageKey: saveSlots.keyFor(activeId, 'scoreboard'))`.

Đổi `static const _storageKey` thành field instance (`final String _storageKey`) — không còn là hằng số static dùng chung.

## Acceptance criteria
- [x] `LocalScoreboardService()` (không truyền `storageKey`): hành vi/dữ liệu y hệt hiện tại, đọc đúng key `'local_scoreboard_v1'` cũ — không phá bất kỳ test/save cũ nào.
- [x] `LocalScoreboardService(storageKey: 'custom_key')`: đọc/ghi đúng vào `'custom_key'`, hoàn toàn độc lập với instance dùng key mặc định (2 instance, 2 key khác nhau, không đụng dữ liệu nhau).
- [x] 2 instance `LocalScoreboardService` với 2 `storageKey` khác nhau hoạt động độc lập hoàn toàn: `submitScore`/`topN`/`entriesAround` của instance này không ảnh hưởng instance kia.
- [x] Không đổi hành vi `submitScore`/`topN`/`entriesAround`/`capacity` hiện có; không phá bất kỳ test nào trong `test/core/local_scoreboard_service_test.dart`.
- [x] Test: unit test đầy đủ mọi case trên (bao gồm 1 test tích hợp minh hoạ đúng use-case: dùng `SaveSlotManager.keyFor` làm `storageKey`).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-69-local-scoreboard-service-custom-storage-key.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/local_scoreboard_service.dart` (đặc biệt cách `_storageKey` được dùng trong `_store`/`_hydrate`) và `test/core/local_scoreboard_service_test.dart` hiện có trước khi sửa. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, default `null` giữ nguyên key cũ tuyệt đối không phá save cũ của consumer app hiện có, không phá API/test hiện có, không over-engineer — chỉ 1 param, không thêm cơ chế migrate key phức tạp).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria, bao gồm 1 test minh hoạ đúng use-case nối với `SaveSlotManager.keyFor`.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (service thuần, không bắt buộc đụng `example/`).
4. Không cần device smoke test (thay đổi core service thuần, không có UI liên quan trực tiếp).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `local_scoreboard_service.dart`: `_storageKey` là `static const`, không có param nào trong constructor để override. Xác nhận `SaveSlotManager.keyFor` (IDEA-56, đã done) đã tồn tại đúng như mô tả (`lib/core/save_slot_manager.dart`), nên đây là cầu nối thật sự khả thi giữa 2 tính năng đã có, không phải suy đoán. Effort nhỏ (1 param + đổi `static const` thành field instance), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Đổi `static const _storageKey` thành field instance `final String _storageKey`, khởi tạo `storageKey ?? 'local_scoreboard_v1'` trong initializer list — 1 dòng, không đụng gì khác trong toàn bộ file (`_store`/`_hydrate`/mọi chỗ dùng `_storageKey` giữ nguyên, chỉ đổi từ hằng số sang field).

**Test:** 5 test mới trong `test/core/local_scoreboard_service_test.dart` nhóm "ENH-69" — mặc định giữ đúng key cũ, 2 instance 2 key độc lập hoàn toàn, persist đúng qua restart với key tuỳ chỉnh, không đổi hành vi `submitScore`/`topN`/`capacity`, và quan trọng nhất: 1 test tích hợp dùng thẳng `SaveSlotManager.keyFor()` làm `storageKey` — chứng minh đúng use-case cầu nối đã nêu trong task, không chỉ là tham số trừu tượng.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1199/1199 pass. Không đụng `example/` (service thuần, không bắt buộc demo).

**Tự chấm điểm: 9.5/10** — đúng yêu cầu, default giữ nguyên tuyệt đối key cũ (không phá save nào của consumer app hiện có), có test tích hợp thật chứng minh đúng use-case ban đầu (nối `SaveSlotManager` với `LocalScoreboardService`) thay vì chỉ test tham số đơn lẻ, tất cả 30 test pass ngay lần đầu không cần sửa.
