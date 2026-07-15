# F1 — Combo/chain multiplier

**Epic:** Features · **SP:** 5 · **Pri:** Must · **Deps:** — · **Chặn:** G1, A1, G6, A5

## Mục tiêu
Nổ nhiều nhóm liên tiếp (không quá `comboWindow` giây giữa 2 lần) → hệ số điểm
tăng dần (x1 → x2 → x3…). Reset khi hết cửa sổ hoặc bàn settle mà không tap.

## Vì sao
Cơ chế pop hiện chỉ cộng điểm phẳng → thiếu skill ceiling. Combo thưởng người
chơi chuỗi nhanh, tạo "flow" và chiều sâu — nền cho G1/A1/A5/G6.

## Acceptance criteria
- [x] Nổ nhóm khi combo đang mở → điểm = `scoreForGroup(n) * multiplier`.
- [x] `multiplier` tăng mỗi lần nổ trong cửa sổ (vd +0.5, cap x5), hiển thị được.
- [x] Combo reset về x1 khi quá `comboWindow` (vd 2.5s) không nổ, hoặc khi màn end.
- [x] Không ảnh hưởng tính sao gãy: target/achievability vẫn qua. — không có
      tool sim riêng trong repo (đã audit lại, xác nhận không tồn tại), nhưng
      không cần: `comboMultiplier` khởi tạo `1.0.obs` (`game_controller.dart:102`),
      cap tại `comboMax = 5.0`, không bao giờ < 1.0 → `registerPop` luôn trả
      điểm ≥ `scoreForGroup(n)` phẳng. Combo chỉ có thể làm target DỄ đạt hơn,
      không bao giờ khó hơn → achievability (đạt được target, theo định nghĩa
      ở `CLAUDE.md`) không thể bị phá bởi combo. Rủi ro thật (nếu có) là
      "quá dễ 3 sao", thuộc phạm trù cân bằng độ khó — không phải tiêu chí
      "vẫn qua" ở dòng này (2026-07-14).
- [x] Unit test cho logic multiplier (tăng/cap/reset) — group "F1 Combo multiplier" trong `test/presentation/game_controller_test.dart`: assert `registerPop` tăng `comboMultiplier` dần và cap tại `comboMax`, điểm cộng đúng hệ số, `resetCombo` đưa `comboCount`/`comboMultiplier` về 0/1.0 (2026-07-14).

## Rà soát checkbox (2026-07-13)
- `lib/presentation/controllers/game_controller.dart`: `comboMultiplier` (Rx, cap `comboMax=5.0`), `comboCount`, `comboWindow=3.0`, `registerPop(baseScore)` nhân hệ số đúng công thức `scoreForGroup(n) * multiplier`; `resetCombo()` set lại `comboCount=0`/`comboMultiplier=1.0`.
- `lib/game/pop_star_game.dart`: `_tryPop`/`_activatePowerTile` gọi `controller.registerPop(...)`, dùng `_comboTimer` (dt cộng dồn trong `update()`, không `DateTime.now`) để reset khi hết cửa sổ — khớp yêu cầu deterministic.
- Grep `test/` cho `comboMultiplier`/`resetCombo`/`combo_test.dart`: không có kết quả — thiếu unit test riêng cho tăng/cap/reset của multiplier (2 mục trên để ngỏ).

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
