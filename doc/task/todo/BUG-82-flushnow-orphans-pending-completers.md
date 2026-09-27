---
id: BUG-82
title: "flushNow treo mọi requestCheckpoint đang chờ"
type: bug
priority: P0
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/checkpoint_coordinator.dart:152` `flushNow`.

## Hiện trạng

`flushNow` public không drain `_pendingCompleters` — chỉ nhánh `requestCheckpoint(critical: true)` gọi `_completePending` (dòng 117-118). Ai gọi `flushNow()` trực tiếp trong lúc còn debounce pending sẽ treo mọi `requestCheckpoint` đang chờ future đó mãi mãi.

## Vì sao cần / Hậu quả

Future treo vĩnh viễn = leak + logic chờ checkpoint (save-before-exit) không bao giờ chạy.

## Đề xuất

`flushNow` tự drain `_pendingCompleters` với chính kết quả của nó (gộp `_completePending` vào cuối `flushNow`), hoặc document rõ + route mọi caller qua `requestCheckpoint(critical: true)`.

## Acceptance criteria

- [ ] Unit test gọi `flushNow` giữa debounce → mọi pending future đều resolve (không treo).
- [ ] Không double-complete completer khi `critical` + `flushNow` chồng nhau.

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

Cao. Đã verify `flushNow` dòng 152 không chạm `_pendingCompleters`, `_completePending` chỉ được gọi từ `requestCheckpoint` dòng 118 và debounce callback dòng 126.
