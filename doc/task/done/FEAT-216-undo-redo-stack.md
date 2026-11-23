---
id: FEAT-216
title: "UndoStack<T> dùng chung, có giới hạn, snapshot-based, kèm nút hoàn tác trong Match-3 demo"
type: feature
layer: lib/core + example
priority: P3
effort: S
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

Puzzle game gần như luôn cần hoàn tác; kit chưa có (quét `lib`: không có undo/redo).

## Phạm vi đề xuất

- `UndoStack<T>` thuần Dart: `push(snapshot)`, `undo()`, `redo()`, `canUndo/canRedo`, giới hạn dung lượng (`capacity` > 0, kiểm bằng `ArgumentError` theo ENH-85), `clear()`; `push` sau khi undo xoá nhánh redo.
- Snapshot-based (lưu bản sao bất biến do caller đưa), không tự clone sâu. Ghi rõ: caller chịu trách nhiệm immutability của `T`.
- Test: thứ tự, tràn dung lượng bỏ bản cũ nhất, redo bị xoá khi push mới, `undo` trên stack rỗng trả `null` không ném; mutation check.
- Example (tuỳ chọn, demo sơ sơ): nút hoàn tác trong Match-3 Lite, tốn 1 lượt/xu hay miễn phí do owner chọn; cần lưu trạng thái `Match3Engine` (xem `engine` snapshot có sẵn không, nếu chưa thì giới hạn demo).

## Câu hỏi mở

Có tích hợp Match-3 demo ở bản đầu hay chỉ phát hành `UndoStack` (owner đã nói demo chỉ cần sơ sơ).

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Chốt API `UndoStack<T>` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [x] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [x] 3. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [x] 4. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [x] 5. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [x] 6. (Tuỳ chọn, chỉ khi owner muốn) nút hoàn tác trong Match-3 Lite: kiểm `Match3Engine` có snapshot trạng thái chưa; nếu chưa, ghi giới hạn và bỏ bước này. Thêm test widget trong `example/test/match3_lite_screen_test.dart`.
- [x] 7. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] push sau undo xoá nhánh redo; tràn dung lượng bỏ bản cũ nhất.
- [x] `undo`/`redo` trên stack rỗng trả `null`, không ném.
- [x] `capacity <= 0` là `ArgumentError`.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`

## Kết quả thực hiện (2026-11-23)

- Phạm vi đã phát hành: chỉ `UndoStack<T>` (`lib/core/utils/undo_stack.dart`), pure Dart. Tích hợp nút hoàn tác vào Match-3 Lite KHÔNG làm: `Match3Engine` không có cơ chế snapshot/khôi phục trạng thái (grep `snapshot|toJson|copy` chỉ ra các hằng `Match3Level`), owner nói demo chỉ cần sơ sơ, và nút hoàn tác cần quyết định kinh tế (tốn lượt hay xu). Bước tuỳ chọn trong task đã bỏ, có thể mở thành task riêng nếu muốn.
- API: `push`, `undo`, `redo`, `canUndo`, `canRedo`, `current`, `length`, `clear`, `capacity`. `capacity <= 0` là `ArgumentError`. `undo/redo` ở biên trả `null`, không đổi trạng thái.
- Quy ước chốt: `capacity` tính cả snapshot hiện tại (`capacity: 1` thì không bao giờ undo được); push sau undo xoá nhánh redo; tràn thì bỏ snapshot CŨ NHẤT. Stack không sao chép, ghi trong dartdoc: `T` phải bất biến.
- Test: 8 test (tham số, rỗng, undo/redo theo thứ tự, push sau undo, tràn dung lượng, capacity 1, clear, 5000 thao tác ngẫu nhiên có seed giữ bất biến). Mutation: giữ nhánh redo làm 1 test đỏ, bỏ giới hạn làm 3 đỏ, bỏ nhầm snapshot mới nhất làm 2 đỏ, lệch một ở `canUndo` làm 4 đỏ.
- Kiểm chứng: analyze sạch, root 4152 pass, API snapshot thêm `UndoStack` (+7 dòng), CHANGELOG `## Unreleased`, 5 quality-gate xanh (chạy riêng từng tool).
