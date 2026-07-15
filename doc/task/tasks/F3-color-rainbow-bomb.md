# F3 — Booster color/rainbow bomb

**Epic:** Features · **SP:** 5 · **Pri:** Should · **Deps:** — (nên sau A1 để tái dùng anim pop)

## Mục tiêu
Booster mới thứ 4: **Rainbow bomb** — arm rồi tap 1 ô → xoá TẤT CẢ ô cùng màu ô đó
trên toàn bàn, rồi gravity/collapse.

## Vì sao
Đa dạng booster, cảm giác "quét sạch" đã tay, thêm điểm monetize (bán bằng xu).

## Acceptance criteria
- [x] Shop bán Rainbow bomb (giá vd 80 xu); Game HUD có nút thứ 4 + số lượng.
- [x] Arm → tap ô hợp lệ → mọi ô cùng màu nổ (dùng anim pop + hạt), trừ 1 lượt.
- [x] Tap ngoài bàn / ô trống → không tiêu. — audit note dòng này đã stale
      (trỏ `useRainbow` dòng 739 "trừ vô điều kiện" nhưng code hiện tại đã
      đúng): `triggerRainbow` trả `bool` (`false` khi `targetColor` null/<0
      hoặc `_animating`), `useRainbow` check `if (!activeGame!.triggerRainbow(...)) return;`
      trước khi trừ `rainbowCount` — cùng pattern void→bool đã áp cho
      bomb/shuffle/undo/swap. Thêm test no-op trong
      `test/widget/rainbow_bomb_test.dart` ("F3: tap ô obstacle (không màu
      thật) → không tiêu lượt") để chốt lại, trước đây chưa có test (2026-07-14).
- [x] Sau nổ: gravity/collapse + check end như thường.
- [x] Unit test logic "chọn mọi ô theo màu".

## Rà soát checkbox (2026-07-13)
- `GameController.rainbowPrice = 80`; `shop_screen.dart` có `_BoosterRow` Rainbow; `game_screen.dart` `_Hud` có nút booster thứ 4 đọc `gameCtrl.rainbowCount.value`.
- `triggerRainbow(row,col)` (`lib/game/pop_star_game.dart` dòng 653): gom `colorGrid[r][c]==targetColor` rồi gọi `_clearAndCollapse` (tái dùng anim pop/hạt + gravity/collapse + `_checkEnd()` như flow thường).
- `test/widget/rainbow_bomb_test.dart`: test xoá đúng mọi ô cùng màu trên bàn caro 2 màu, không cộng điểm, trừ đúng 1 lượt — xác nhận unit test logic "chọn theo màu".
- Riêng nhánh "tap ô trống/obstacle không tiêu lượt" KHÔNG có test và code thực tế trừ lượt vô điều kiện — xem ghi chú ở dòng criterion tương ứng.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: `triggerRainbow(row,col)` — gom mọi ô `colorGrid[r][c]==targetColor`
   → tái dùng `_clearAndCollapse(cells)` (đã có).
2. `lib/presentation/controllers/game_controller.dart`: `rainbowCount` (RxInt), `buyRainbow`,
   `useRainbow(row,col)`, `StorageKeys.rainbowCount`.
3. `lib/presentation/controllers/game_screen_controller.dart`: `BoosterMode.rainbow` +
   nhánh trong `handleBoardTap` (dùng `game.cellAt`).
4. UI: `shop_screen.dart` thêm row; `game_screen.dart` `_Hud` thêm `_BoosterButton`.
5. i18n key tên/mô tả (en+vi). Test: `test/presentation/rainbow_bomb_test.dart`.

## Ghi chú kỹ thuật
Tái dùng hạ tầng booster bomb sẵn có (arm/consume/guard). `_clearAndCollapse` đã
nhận `Set<Point>` nên chỉ cần tập ô cùng màu.

DoD chung: `../README.md`.
