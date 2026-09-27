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

- [ ] Test throw khi xóa data → metadata + active giữ nguyên.
- [ ] Xóa thành công → prefix data, metadata, active (nếu trỏ slot) cùng biến mất.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

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
