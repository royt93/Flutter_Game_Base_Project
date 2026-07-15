# G7 — Neon edge-trace nhóm chọn

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** G1 (dùng chung preview nhóm)

## Mục tiêu
Khi preview/chọn nhóm (G1), vẽ **viền neon chạy** quanh BIÊN của cả nhóm (đường
sáng dashed/chuyển động) thay vì chỉ glow từng ô.

## Vì sao
Chỉ rõ ranh giới nhóm sẽ nổ, đẹp mắt, "cao cấp" — hỗ trợ quyết định + juice.

## Acceptance criteria
- [x] Tính được đường biên (outline) của tập ô nhóm (union các cạnh ngoài).
- [x] Vẽ viền sáng chạy (marching ants / gradient sweep) quanh biên khi preview.
- [x] Cập nhật khi nhóm đổi (kéo ngón); tắt khi thả.
- [x] 60fps kể cả nhóm lớn.

## Rà soát checkbox (2026-07-13)
- `lib/game/pop_star_game.dart:397-421` `_updateEdgeTrace()`: với mỗi ô
  trong `_preview`, cạnh nào có ô kề KHÔNG thuộc nhóm → thêm đoạn thẳng —
  đúng "union cạnh ngoài".
- `_EdgeTraceComponent` (đầu file, ~dòng 28-56): render alpha sweep theo
  `sin(_phase + i*0.6)`, `_phase` tăng theo `dt` — hiệu ứng chạy, đúng
  phương án "vẽ từng đoạn với alpha sweep" mà ghi chú kỹ thuật cho phép.
- Gọi từ `previewGroup()` khi nhóm đổi, xoá segments trong `clearPreview()`
  → tắt khi thả. O(kích thước nhóm), không rebuild path phức tạp mỗi frame.

## Subtasks (gợi ý file)
1. Logic biên: từ `Set<Point>` nhóm → danh sách cạnh ngoài (cạnh mà ô kề không thuộc nhóm).
2. `lib/game/pop_star_game.dart` hoặc component riêng: vẽ path biên (theo cell size +
   offset board) với hiệu ứng chạy (dashPhase theo dt).
3. Tích hợp vào luồng preview của G1.

## Ghi chú kỹ thuật
Biên = gộp các đoạn cạnh; nối thành path để dash chạy mượt (hoặc vẽ từng đoạn với
alpha sweep nếu nối path phức tạp). Làm CHUNG với G1 để tái dùng dữ liệu nhóm.

DoD chung: `../README.md`.
