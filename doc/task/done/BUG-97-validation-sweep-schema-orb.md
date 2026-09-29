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

- [x] Reserved keyword bị reject kèm test codegen.
- [x] Mutate field list sau validate không đổi schema.
- [x] Viewport tí hon không throw.

## Quyết định

(a) `lib/core/utils/remote_schema_compiler.dart`: thêm `_reservedWords` (đúng danh sách reserved word thật của Dart, KHÔNG gồm `await`/`yield` — đó là contextual keyword chỉ reserved bên trong thân hàm async/generator, hợp lệ làm identifier ở mọi nơi khác, và generated model code luôn sync) + helper `_isValidIdentifier` = regex cũ AND không nằm trong reserved set. Áp dụng cho cả `packName` lẫn từng field name.

(b) Cùng file: vòng lặp validate giờ deep-copy `fields` của TỪNG version qua `List.unmodifiable` (không chỉ freeze list `versions` ngoài như code cũ), nên mutate list gốc caller giữ reference sau khi validate không ảnh hưởng schema đã tạo, và mutate trực tiếp `schema.current.fields` throw `UnsupportedError`. `RemoteSchemaDef._` constructor là library-private nên không có đường bypass validate.

(c) `lib/presentation/game/roy_game.dart`: tách `_clampToBounds(value, radius, extent)` — khi `extent - radius < radius` (viewport nhỏ hơn 2x bán kính orb) fallback về `extent / 2` thay vì gọi `clamp()` với lower > upper (throw `ArgumentError`).

TDD: viết test đỏ trước cho cả 3 case (2 unit test packName/field reserved keyword + 1 unit test built-in identifier vẫn hợp lệ, 2 unit test deep-freeze, 1 widget test viewport tí hon, 1 CLI end-to-end test), verify fail đúng lý do, rồi implement tới khi xanh.

Audit fork độc lập (2 vòng): vòng 1 chấm 9.0/10, tìm ra gap thật — `_reservedWords` ban đầu có cả `await`/`yield`, nhưng đó là contextual keyword nên reject là regression hành vi không cần thiết (schema hợp lệ trước đây giờ bị từ chối oan). Đã fix (bỏ 2 từ đó khỏi set, thêm comment giải thích + 1 test regression riêng chứng minh cả packName và field name dùng `await`/`yield` vẫn được chấp nhận). Rescore vòng 2 từ CÙNG fork: **9.5/10** — "Gap closed cleanly, no regressions reopened."

Test coverage: unit (`test/core/utils/remote_schema_compiler_test.dart`: 7 case mới — reserved packName reject, reserved field reject, built-in `dynamic` vẫn hợp lệ, mutate list gốc sau validate không đổi schema, `schema.current.fields` unmodifiable throw khi mutate trực tiếp, và case audit-fix `await`/`yield` vẫn hợp lệ ở cả packName lẫn field), CLI end-to-end (`test/tool/remote_schema_compiler_test.dart`: 1 case — field reserved keyword qua toàn bộ pipeline `dart run` thật, exit 1, không sinh file), widget (`test/presentation/game/roy_game_test.dart`: 1 case — viewport 20x20 với orb bán kính 16, `game.update()` không throw), integration/device (`example/integration_test/app_boot_test.dart`: 1 case mới — chạy CẢ 2 kịch bản (reserved-keyword schema reject + tiny-viewport orb update) trên thiết bị Android thật TECNO KJ7, pass).

Kết quả: `flutter analyze` sạch root + `example/`. `flutter test --exclude-tags slow` sạch root (2487/2487, không flake lần chạy này) + sạch `example/` (195/195). `dart run tool/api_compatibility.dart check` báo `unchanged` (fix nội bộ, không đổi public export). Smoke test device thật TECNO KJ7 pass (build+install+run, cả 2 kịch bản exercise đúng).

Tự chấm ban đầu 9/10 (đã có 3 fix + test đầy đủ trước khi audit) → audit fork độc lập vòng 1 tìm 1 gap thật (contextual keyword over-reject) → fix → rescore vòng 2: **9.5/10**.

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
