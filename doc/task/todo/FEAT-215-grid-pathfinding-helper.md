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

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Chốt API `Grid<T> + findPath (BFS, A*)` (chữ ký, lỗi, biên) trong "Kết quả thực hiện"; trả lời các "Câu hỏi mở" (nếu chưa có owner trả lời, dùng "Đề xuất" ghi trong task và nêu rõ).
- [ ] 2. Viết test TRƯỚC (đỏ) cho các trường hợp biên liệt kê trong Phạm vi, rồi viết cài đặt thuần Dart (không import Flutter).
- [ ] 3. Chốt tie-break deterministic (thứ tự láng giềng cố định) và ghi vào dartdoc; chốt có Dijkstra/chi phí địa hình ở bản đầu hay không (đề xuất: không).
- [ ] 4. Test hiệu năng/độ phức tạp: lưới 200x200 có đường, và lưới bị chặn hoàn toàn trả `null` trong thời gian hợp lý (đặt trần số ô duyệt).
- [ ] 5. Invariant constructor/tham số bằng `ArgumentError` (ENH-85); dữ liệu từ nguồn không tin cậy dùng `SdkResult`, không ném (BUG-112).
- [ ] 6. Mutation check: phá logic chính, test phải đỏ, rồi khôi phục (dùng python/Edit, không dùng sed trên macOS).
- [ ] 7. Export + `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 8. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển file sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Trả `null` khi không có đường; đường ngắn nhất đúng trên các lưới mẫu.
- [ ] Nhiều đường cùng chi phí cho kết quả ổn định giữa các lần chạy.
- [ ] Không import Flutter.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/utils`
