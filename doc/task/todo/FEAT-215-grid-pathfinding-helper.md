---
id: FEAT-215
title: "Grid + pathfinding helper thuần Dart (BFS/A*) cho game lưới"
type: feature
layer: lib/core
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

Khối dựng chung cho game lưới (tower defense, puzzle, roguelike): kit có `match3_engine` nhưng không có tìm đường/lưới tổng quát. Quét `lib` không thấy pathfinding/A*/BFS nào.

## Phạm vi đề xuất

- `Grid<T>` nhỏ (kích thước, ô đi được, láng giềng 4/8 hướng) thuần Dart, không import Flutter.
- `findPath` BFS và A* (heuristic Manhattan/Chebyshev), chi phí ô tuỳ chọn, trả `null` khi không có đường; deterministic (tie-break rõ ràng, không phụ thuộc thứ tự hash).
- Validate tham số bằng `ArgumentError` ở constructor (ENH-85); input không tin cậy dùng `SdkResult`.
- Test: lưới rỗng, bị chặn, đường duy nhất, nhiều đường cùng chi phí (kết quả ổn định), lưới lớn có trần chi phí; mutation check.

## Không làm

Không vật lý, không tilemap loader (đã có `tiled_terrain_collision`), không UI. Cần cập nhật snapshot API gate và CHANGELOG khi thêm export.

## Câu hỏi mở

Có cần Dijkstra/chi phí địa hình ngay từ bản đầu, hay chỉ BFS + A* đơn giản.
