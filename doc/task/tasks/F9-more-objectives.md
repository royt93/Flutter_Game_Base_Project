# F9 — Objective đa dạng hơn (mở rộng F6)

**Epic:** Features · **SP:** 8 (chẻ nhỏ) · **Pri:** Should · **Deps:** F6 (mở rộng enum objective đã có)

## Mục tiêu
Thêm 3 loại objective mới ngoài score/clearColor/clearObstacle (F6): **collect**
(thu N ô màu X), **moveLimitBonus** (hoàn thành trong ≤M lượt → +1 sao bonus),
**obstacleInMoves** (phá Y ô obstacle trong ≤M lượt).

## Vì sao
F6 mới có 3 loại, lặp lại cố định mỗi 5 level suốt 200 màn — thêm biến thể giữ
cảm giác mới mỗi world mà không cần đổi tile/engine.

## Acceptance criteria
- [ ] `LevelObjective` enum thêm 3 case mới, không phá case cũ (F6).
- [ ] HUD hiện đúng progress cho từng loại objective mới.
- [ ] `moveLimitBonus`: đạt trong ≤M lượt → +1 sao bonus (không fail nếu vượt,
      chỉ mất bonus — vẫn thắng nếu đạt objective chính).
- [ ] Unit test mỗi loại objective mới: điều kiện thắng + đếm tiến độ đúng.

## Subtasks (gợi ý file)
1. `lib/data/levels.dart`: case enum mới + tham số (target color/count, move limit).
2. `lib/presentation/controllers/game_controller.dart`: tính tiến độ + sao bonus.
3. `lib/presentation/screens/game_screen.dart`: HUD hiện loại objective mới.
4. Test: `test/data/levels_test.dart` hoặc file mới cho từng loại.

## Ghi chú kỹ thuật
Chẻ nhỏ như F6 — làm từng loại 1, test xanh mới sang loại kế, tránh 1 PR khổng lồ.

DoD chung: `../README.md`.
