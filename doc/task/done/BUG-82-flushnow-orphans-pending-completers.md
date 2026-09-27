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

- [x] Unit test gọi `flushNow` giữa debounce → mọi pending future đều resolve (không treo).
- [x] Không double-complete completer khi `critical` + `flushNow` chồng nhau.

## Quyết định

Tách nguyên văn body cũ của `flushNow` thành `_computeFlush()` (không đổi 1
dòng logic bên trong).

**Sửa sau audit độc lập:** bản đầu gọi `_completePending` SAU KHI `await
_computeFlush()` xong (bên trong `_guard.runExclusive`). Có race thật: 1
`requestCheckpoint()` mới tới trong lúc flush A đang await ghi storage sẽ
bị thêm vào `_pendingCompleters`, rồi flush A (không hề biết request mới
này thuộc chu kỳ khác) drain nhầm nó khi xong — request B nhận "thành
công" của snapshot A dù state của B chưa từng được ghi. Sửa: `flushNow()`
giờ CHỤP + XÓA `_pendingCompleters` và cancel timer NGAY LẬP TỨC (đồng bộ,
trước khi `_guard.runExclusive`/await bắt đầu), rồi chỉ complete đúng danh
sách đã chụp đó — y hệt cách nhánh `critical` cũ (trước BUG-82) vốn đã làm
đúng. `_computeFlush()` không còn tự cancel timer nữa (tránh cancel nhầm
timer của request mới tới sau).

3 test trong `test/core/checkpoint_coordinator_test.dart` (group
`BUG-82`): gọi `flushNow()` trực tiếp trong lúc có pending non-critical →
future resolve trong `.timeout(1s)` (treo mãi mãi với code cũ); (sau audit)
request MỚI đến giữa lúc 1 flush khác đang await storage (dùng
`_BlockingStorageService` chặn ở `setBool` để mô phỏng "đang ghi") → request
đó KHÔNG bị cuỗm mất bởi flush đang chạy, tự chờ timer/flush riêng của
mình; critical + pending non-critical cùng lúc → cả 2 complete, không
double-complete. Toàn bộ group `BUG-42`/`BUG-78` cũ vẫn pass nguyên văn.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root và
`example/`. Không có UI-observable behavior nên không cần device smoke test
riêng — verification qua unit test là đủ.

Tự chấm: 9.5/10.

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
