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
