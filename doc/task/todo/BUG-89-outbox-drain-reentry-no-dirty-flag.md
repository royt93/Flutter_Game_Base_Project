---
id: BUG-89
title: "Outbox drain re-entry bỏ item enqueue giữa vòng xử lý"
type: bug
priority: P1
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/offline_outbox_service.dart:352` `drain`.

## Hiện trạng

`drain` re-entry trả ngay khi `_draining` true (353). Vòng hiện tại snapshot `ordered` một lần (356-358), nên item enqueue trong lúc `_attempt` chạy không có dirty-flag và không thuộc snapshot → chờ lần `drain` sau vô định.

## Vì sao cần / Hậu quả

Khi online auto-drain, event mới có thể bị kẹt dù connectivity tốt.

## Đề xuất

Đặt dirty-flag khi `enqueue` thấy `_draining`; sau vòng snapshot, chạy thêm một vòng khi dirty. Giữ thứ tự priority trong từng vòng và chống infinite loop.

## Acceptance criteria

- [ ] Test enqueue giữa `drain` → item mới được xử lý trong cùng chu kỳ drain.
- [ ] Re-entry không tạo upload song song cho cùng item.

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

Cao. Đã verify re-entry `if (_draining) return` dòng 353 và one-time `ordered` snapshot dòng 356-358; không có dirty flag trong `drain`.
