---
id: BUG-83
title: "Race flush vs set trực tiếp làm mất update"
type: bug
priority: P1
effort: M
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/storage_service.dart:159` `flush`.

## Hiện trạng

`flush` snapshot `_buffer` rồi ghi từng key async qua `_writeDirect`. Một `setInt`/`setString` trực tiếp xen giữa sẽ ghi giá trị mới xuống disk trước, sau đó `flush` ghi giá trị stale (đã snapshot) đè lên sau cùng → mất update. Doc comment trong file chỉ giải quyết chiều ngược lại (buffered-mới vs flush-cũ), không giải quyết direct-write xen giữa flush.

## Vì sao cần / Hậu quả

Hot-path counter (buffered) + transaction thật (unbuffered) trên cùng key = mất tiền/item của player trong điều kiện race thật trên device.

## Đề xuất

Serialize `flush` + mọi write qua cùng 1 save-chain/mutex (mẫu `_saveChain` các ledger service đã dùng, ví dụ `SeasonEventService`); `flush` chụp snapshot DƯỚI lock.

## Acceptance criteria

- [ ] Test concurrent `flush` + `set` xen kẽ → giá trị cuối đúng thứ tự gọi, không mất update.
- [ ] Không phá vỡ đảm bảo hiện tại: direct write luôn thắng buffered stale.

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

Cao. Đã verify `flush` dòng 159-166 snapshot ngoài lock, `_writeDirect` và `setInt` dòng 217-225 ghi độc lập không serialize chung.
