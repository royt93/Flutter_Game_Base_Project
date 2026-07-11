# G6 — Combo heat (bàn nóng sáng dần)

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** F1, (bổ trợ G4)

## Mục tiêu
Combo càng cao → block trên bàn glow "nóng" dần (viền sáng mạnh hơn, ngả ấm), báo
hiệu đang "on fire". Reset khi combo dứt.

## Vì sao
Phản hồi leo thang trực quan ngay trên bàn (khác G4 ở nền) — thưởng chuỗi.

## Acceptance criteria
- [ ] Mức heat suy từ combo (F1); block render glow theo heat (0..1).
- [ ] Heat cao có chỉ báo rõ (vd viền sáng + hơi ngả cam/trắng) nhưng vẫn phân biệt màu.
- [ ] Reset mượt khi combo hết.
- [ ] 60fps (không tạo Paint mới mỗi block mỗi frame nếu tránh được).

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: expose `heat` (0..1) suy từ combo; truyền vào block render.
2. `lib/game/block_component.dart`: `render` cộng thêm lớp rim/glow theo `game.heat`.
3. Đồng bộ với G4 nếu cùng làm (một nguồn `comboEnergy`).

## Ghi chú kỹ thuật
Đọc heat từ game (BlockComponent có ref `game`), tránh set state từng block. Ràng
biên để không phá độ phân biệt màu (accessibility).

DoD chung: `../README.md`.
