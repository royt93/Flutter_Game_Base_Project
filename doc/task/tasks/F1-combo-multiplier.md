# F1 — Combo/chain multiplier

**Epic:** Features · **SP:** 5 · **Pri:** Must · **Deps:** — · **Chặn:** G1, A1, G6, A5

## Mục tiêu
Nổ nhiều nhóm liên tiếp (không quá `comboWindow` giây giữa 2 lần) → hệ số điểm
tăng dần (x1 → x2 → x3…). Reset khi hết cửa sổ hoặc bàn settle mà không tap.

## Vì sao
Cơ chế pop hiện chỉ cộng điểm phẳng → thiếu skill ceiling. Combo thưởng người
chơi chuỗi nhanh, tạo "flow" và chiều sâu — nền cho G1/A1/A5/G6.

## Acceptance criteria
- [ ] Nổ nhóm khi combo đang mở → điểm = `scoreForGroup(n) * multiplier`.
- [ ] `multiplier` tăng mỗi lần nổ trong cửa sổ (vd +0.5, cap x5), hiển thị được.
- [ ] Combo reset về x1 khi quá `comboWindow` (vd 2.5s) không nổ, hoặc khi màn end.
- [ ] Không ảnh hưởng tính sao gãy: target/achievability vẫn qua (chạy lại sim).
- [ ] Unit test cho logic multiplier (tăng/cap/reset).

## Subtasks (gợi ý file)
1. `lib/presentation/controllers/game_controller.dart`: thêm `comboMultiplier` (RxDouble),
   `comboCount` (RxInt), `_lastPopAt`; API `registerPop()` cập nhật hệ số; `addScore`
   nhận điểm đã nhân hoặc thêm `addComboScore(base)`.
2. `lib/game/pop_star_game.dart`: `_tryPop` gọi combo API thay vì addScore phẳng.
3. Timer reset combo: dùng dt trong game loop (không `DateTime.now`) hoặc TimerComponent.
4. Test: `test/presentation/combo_test.dart` — chuỗi nổ tăng hệ số, quá cửa sổ reset.

## Ghi chú kỹ thuật
Cửa sổ combo đo bằng thời gian game (dt cộng dồn) để test deterministic. Cân bằng:
sau khi thêm multiplier, chạy `tool` sim achievability lại để target vẫn hợp lý
(có thể cần nâng nhẹ target hoặc cap multiplier).

DoD chung: `../README.md`.
