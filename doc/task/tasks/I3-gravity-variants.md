# I3 — Gravity variants

**Epic:** Features · **SP:** 8 · **Pri:** Could · **Deps:** none (đụng `pop_collapse.dart`, làm sau F6)

## Mục tiêu
Vài level đảo hướng gravity (lên/trái/phải) thay vì luôn rơi xuống — tạo biến
thể puzzle mới bằng đổi luật, không cần thêm tile.

## Vì sao
Đa dạng cảm giác chơi với chi phí thấp hơn nhiều so với thêm tile/obstacle
mới — chỉ đổi 1 tham số luật chơi.

## Acceptance criteria
- [x] `PopLevel` thêm field `gravityDirection` (mặc định `down`; vài level dùng
      `up`/`left`/`right`).
- [x] `applyGravityAndCollapse` nhận tham số direction, tái dùng thuật toán
      down hiện có qua transpose/reflect grid (không viết lại 4 lần).
- [x] `BlockComponent`/animation rơi đúng hướng (MoveToEffect theo direction).
- [x] Unit test: gravity up/left/right cho kết quả đúng như down đã transpose.

## Rà soát checkbox (2026-07-13)
- Grep xác nhận `gravityDirection` field (`lib/data/levels.dart`), dùng ở
  `lib/game/pop_star_game.dart` (dòng 849, 1184) và `lib/logic/pop_collapse.dart`.
- `applyGravityAndCollapse`/`transformForDirection` tái dùng transpose/reverse
  (đọc trực tiếp `pop_collapse.dart`, không có 4 bộ logic riêng).
- `test/logic/pop_collapse_test.dart` có group `I3: gravityDirection` test up/left/right.

## Subtasks (gợi ý file)
1. `lib/logic/pop_collapse.dart`: thêm tham số direction + helper transpose,
   gọi lại logic down sẵn có sau khi transpose.
2. `lib/data/levels.dart`: field mới, gán vài level dùng variant.
3. `lib/game/pop_star_game.dart`: animate rơi theo direction.

## Ghi chú kỹ thuật
Transpose grid rồi gọi lại hàm down hiện có — không viết 4 bộ logic riêng cho
4 hướng (ladder bậc 2: tái dùng code đã có).

DoD chung: `../README.md`.
