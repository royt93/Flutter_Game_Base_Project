# F10 — Booster Swap + Freeze

**Epic:** Features · **SP:** 8 · **Pri:** Could · **Deps:** F3 (tái dùng khung arm/consume booster)

## Mục tiêu
2 booster mới: **Swap** — chọn 2 ô bất kỳ (không cần liền kề), đổi màu 2 ô, tự
tap tiếp sau đó. **Freeze** — dùng ngay, N lượt kế obstacle không giảm bền dù
nổ cạnh (chỉ hữu ích ở level có obstacle, F6).

## Vì sao
Đa dạng công cụ chiến thuật ngoài bomb/rainbow (phá): swap là hỗ trợ setup
nước đi, freeze là phòng thủ — không trùng cơ chế đã có.

## Acceptance criteria
- [x] Shop bán Swap + Freeze; HUD thêm 2 nút booster.
- [x] Swap: arm → tap ô 1 → tap ô 2 → đổi màu 2 ô, không tự nổ, trừ 1 lượt dùng.
- [x] Freeze: arm → dùng ngay (không cần tap ô) → N lượt kế obstacle không giảm
      bền; tự hết hiệu lực sau N lượt.
- [x] Unit test: swap đổi đúng 2 ô; freeze chặn giảm bền đúng N lượt rồi tự hết.

## Subtasks (gợi ý file)
1. `lib/presentation/controllers/game_controller.dart`: `swapCount`/`freezeCount`
   (RxInt), `buySwap`/`buyFreeze`, `useSwap`/`useFreeze`.
2. `lib/presentation/controllers/game_screen_controller.dart`: `BoosterMode.swap`/`freeze`.
3. `lib/game/pop_star_game.dart`: `triggerSwap(a,b)`; counter `freezeTurnsLeft`
   đọc trong `chipAdjacentObstacles()` (obstacle.dart) — bỏ qua giảm bền khi > 0.
4. UI: `shop_screen.dart`, `game_screen.dart` HUD; i18n.

## Ghi chú kỹ thuật
Tái dùng khung arm/consume của F3 (rainbow), không viết lại state machine booster.

DoD chung: `../README.md`.

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `game_controller.dart` (`buySwap`/`buyFreeze`/`useSwap`/`useFreeze`),
`game_screen_controller.dart` (`toggleSwapArm`, swap 2-tap flow, `useFreeze` dùng ngay),
`pop_star_game.dart` (`triggerSwap` không tự nổ, `freezeTurnsLeft` chặn `chipAdjacentObstacles`),
`shop_screen.dart`/`game_screen.dart` HUD, test `test/widget/swap_freeze_test.dart`
(4 test, đã chạy pass).
