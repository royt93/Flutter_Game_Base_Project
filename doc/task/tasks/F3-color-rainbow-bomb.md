# F3 — Booster color/rainbow bomb

**Epic:** Features · **SP:** 5 · **Pri:** Should · **Deps:** — (nên sau A1 để tái dùng anim pop)

## Mục tiêu
Booster mới thứ 4: **Rainbow bomb** — arm rồi tap 1 ô → xoá TẤT CẢ ô cùng màu ô đó
trên toàn bàn, rồi gravity/collapse.

## Vì sao
Đa dạng booster, cảm giác "quét sạch" đã tay, thêm điểm monetize (bán bằng xu).

## Acceptance criteria
- [ ] Shop bán Rainbow bomb (giá vd 80 xu); Game HUD có nút thứ 4 + số lượng.
- [ ] Arm → tap ô hợp lệ → mọi ô cùng màu nổ (dùng anim pop + hạt), trừ 1 lượt.
- [ ] Tap ngoài bàn / ô trống → không tiêu.
- [ ] Sau nổ: gravity/collapse + check end như thường.
- [ ] Unit test logic "chọn mọi ô theo màu".

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
