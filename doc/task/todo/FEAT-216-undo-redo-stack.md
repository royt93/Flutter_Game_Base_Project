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

- [ ] 1. Chốt API `UndoStack<T>` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [ ] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [ ] 3. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [ ] 4. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [ ] 5. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 6. (Tuỳ chọn, chỉ khi owner muốn) nút hoàn tác trong Match-3 Lite: kiểm `Match3Engine` có snapshot trạng thái chưa; nếu chưa, ghi giới hạn và bỏ bước này. Thêm test widget trong `example/test/match3_lite_screen_test.dart`.
- [ ] 7. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] push sau undo xoá nhánh redo; tràn dung lượng bỏ bản cũ nhất.
- [ ] `undo`/`redo` trên stack rỗng trả `null`, không ném.
- [ ] `capacity <= 0` là `ArgumentError`.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`
