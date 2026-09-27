---
id: BUG-97
title: "Validation sweep schema và orb"
type: bug
priority: P1
effort: S
source: "codex độc lập"
---

## Vị trí

(a)(b) `lib/core/utils/remote_schema_compiler.dart:61`; (c) `lib/presentation/game/roy_game.dart:223`.

## Hiện trạng

(a) Identifier validation chấp nhận reserved keyword Dart (`class`), codegen tạo class/source không compile. (b) Schema immutable nhưng giữ reference list field; mutate sau validate có thể thay đổi schema đã verify. (c) Viewport nhỏ hơn 2x bán kính orb làm `clamp(radius, bounds-radius)` invalid, có thể throw.

## Vì sao cần / Hậu quả

Content pipeline sinh code hỏng; demo crash ở viewport tí hon/thiết bị lạ.

## Đề xuất

(a) từ chối reserved set, test codegen compile; (b) deep-freeze/clone khi validate; (c) guard min bounds, test viewport tí hon không throw.

## Acceptance criteria

- [ ] Reserved keyword bị reject kèm test codegen.
- [ ] Mutate field list sau validate không đổi schema.
- [ ] Viewport tí hon không throw.

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

Cao. Đã verify `_identifierPattern` dòng 61 không loại reserved, `RemoteSchemaDef` giữ sorted list, orb clamp dòng 223 với `bounds-radius`.
