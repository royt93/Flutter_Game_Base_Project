---
id: BUG-81
title: "importWithPrefix rewrite toàn store, kill giữa chừng mất profile"
type: bug
priority: P0
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/storage_service.dart:430` `importWithPrefix`.

## Hiện trạng

`importWithPrefix` merge prefix-data với phần còn lại của store rồi gọi `importAll(merged)` → `_replaceAll` xóa-ghi TOÀN store chỉ để restore 1 prefix. Kill (OS low-memory, crash) giữa chừng mất cả profile ngoài prefix. Rollback trong `importAll` chỉ cứu Dart exception, không cứu killed process.

## Vì sao cần / Hậu quả

Restore 1 save slot không được phép đặt cược toàn bộ profile. Blast radius phải đúng bằng prefix đang restore.

## Đề xuất

Chỉ xóa/ghi đúng key có prefix: diff key prefix hiện tại vs `data`, remove key thừa + set từng key mới, mỗi key có try/catch, không qua `_replaceAll`. `removeAllWithPrefix` (dòng 391) đã làm đúng mẫu này — copy shape đó.

## Acceptance criteria

- [ ] Kill-safe cho key ngoài prefix (key ngoài prefix không bao giờ bị xóa/ghi lại).
- [ ] Key prefix thiếu trong `data` bị xóa (giữ ngữ nghĩa replace-scoped).
- [ ] Key ngoài prefix nguyên vẹn sau restore.
- [ ] Unit test kill-giữa (fake throw giữa chừng) + test round-trip `exportWithPrefix`/`importWithPrefix`.

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

Cao. Đã verify `importWithPrefix` dòng 430 gọi `importAll(merged)`, `_replaceAll` xóa toàn bộ key rồi ghi lại, và `removeAllWithPrefix` dòng 391 đã xóa scoped đúng mẫu cần copy.
