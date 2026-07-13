# I3 — Gravity variants

**Epic:** Features · **SP:** 8 · **Pri:** Could · **Deps:** none (đụng `pop_collapse.dart`, làm sau F6)

## Mục tiêu
Vài level đảo hướng gravity (lên/trái/phải) thay vì luôn rơi xuống — tạo biến
thể puzzle mới bằng đổi luật, không cần thêm tile.

## Vì sao
Đa dạng cảm giác chơi với chi phí thấp hơn nhiều so với thêm tile/obstacle
mới — chỉ đổi 1 tham số luật chơi.

## Acceptance criteria
- [ ] `PopLevel` thêm field `gravityDirection` (mặc định `down`; vài level dùng
      `up`/`left`/`right`).
- [ ] `applyGravityAndCollapse` nhận tham số direction, tái dùng thuật toán
      down hiện có qua transpose/reflect grid (không viết lại 4 lần).
- [ ] `BlockComponent`/animation rơi đúng hướng (MoveToEffect theo direction).
- [ ] Unit test: gravity up/left/right cho kết quả đúng như down đã transpose.

## Subtasks (gợi ý file)
1. `lib/logic/pop_collapse.dart`: thêm tham số direction + helper transpose,
   gọi lại logic down sẵn có sau khi transpose.
2. `lib/data/levels.dart`: field mới, gán vài level dùng variant.
3. `lib/game/pop_star_game.dart`: animate rơi theo direction.

## Ghi chú kỹ thuật
Transpose grid rồi gọi lại hàm down hiện có — không viết 4 bộ logic riêng cho
4 hướng (ladder bậc 2: tái dùng code đã có).

DoD chung: `../README.md`.
