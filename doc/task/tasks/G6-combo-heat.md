# G6 — Combo heat (bàn nóng sáng dần)

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** F1, (bổ trợ G4)

## Mục tiêu
Combo càng cao → block trên bàn glow "nóng" dần (viền sáng mạnh hơn, ngả ấm), báo
hiệu đang "on fire". Reset khi combo dứt.

## Vì sao
Phản hồi leo thang trực quan ngay trên bàn (khác G4 ở nền) — thưởng chuỗi.

## Acceptance criteria
- [x] Mức heat suy từ combo (F1); block render glow theo heat (0..1).
- [x] Heat cao có chỉ báo rõ (vd viền sáng + hơi ngả cam/trắng) nhưng vẫn phân biệt màu.
- [x] Reset mượt khi combo hết.
- [x] 60fps (không tạo Paint mới mỗi block mỗi frame nếu tránh được).

## Rà soát checkbox (2026-07-13)
- `lib/game/pop_star_game.dart:574-578`: `heat` = hàm của `comboMultiplier`
  (0..1, clamp), suy trực tiếp từ combo F1.
- `lib/game/block_component.dart:326-338`: rim stroke lerp cam→trắng theo
  `heat`, không đổi màu thân → vẫn phân biệt màu; `heat` đọc lại mỗi frame
  nên tự về 0 mượt khi combo reset (không cần state riêng).
- Comment ponytail dòng 322-325: cố tình bỏ `MaskFilter.blur` per-block/frame
  (nguồn lag chính), chỉ giữ stroke `Paint` rẻ — đáp ứng tinh thần "tránh chi
  phí perf mỗi frame" dù vẫn tạo 1 `Paint()` nhẹ khi heat>0.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: expose `heat` (0..1) suy từ combo; truyền vào block render.
2. `lib/game/block_component.dart`: `render` cộng thêm lớp rim/glow theo `game.heat`.
3. Đồng bộ với G4 nếu cùng làm (một nguồn `comboEnergy`).

## Ghi chú kỹ thuật
Đọc heat từ game (BlockComponent có ref `game`), tránh set state từng block. Ràng
biên để không phá độ phân biệt màu (accessibility).

DoD chung: `../README.md`.
