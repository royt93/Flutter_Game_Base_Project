# G7 — Neon edge-trace nhóm chọn

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** G1 (dùng chung preview nhóm)

## Mục tiêu
Khi preview/chọn nhóm (G1), vẽ **viền neon chạy** quanh BIÊN của cả nhóm (đường
sáng dashed/chuyển động) thay vì chỉ glow từng ô.

## Vì sao
Chỉ rõ ranh giới nhóm sẽ nổ, đẹp mắt, "cao cấp" — hỗ trợ quyết định + juice.

## Acceptance criteria
- [ ] Tính được đường biên (outline) của tập ô nhóm (union các cạnh ngoài).
- [ ] Vẽ viền sáng chạy (marching ants / gradient sweep) quanh biên khi preview.
- [ ] Cập nhật khi nhóm đổi (kéo ngón); tắt khi thả.
- [ ] 60fps kể cả nhóm lớn.

## Subtasks (gợi ý file)
1. Logic biên: từ `Set<Point>` nhóm → danh sách cạnh ngoài (cạnh mà ô kề không thuộc nhóm).
2. `lib/game/pop_star_game.dart` hoặc component riêng: vẽ path biên (theo cell size +
   offset board) với hiệu ứng chạy (dashPhase theo dt).
3. Tích hợp vào luồng preview của G1.

## Ghi chú kỹ thuật
Biên = gộp các đoạn cạnh; nối thành path để dash chạy mượt (hoặc vẽ từng đoạn với
alpha sweep nếu nối path phức tạp). Làm CHUNG với G1 để tái dùng dữ liệu nhóm.

DoD chung: `../README.md`.
