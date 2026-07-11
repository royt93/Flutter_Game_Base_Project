# F5 — Power tiles / super gems

**Epic:** Features · **SP:** 13 (chẻ nhỏ trước khi làm) · **Pri:** Could · **Deps:** F1

## Mục tiêu
Nổ nhóm lớn sinh **tile đặc biệt** nằm lại trên bàn, tap để kích hoạt:
- ≥5 ô → **Line clear** (xoá 1 hàng hoặc cột).
- ≥7 ô → **Bomb** (nổ 5×5).
- ≥9 ô → **Rainbow** (xoá toàn bộ 1 màu).

## Vì sao
Chiều sâu chiến thuật đỉnh (Toon Blast/Blast game). Người chơi "gài" combo để tạo
power tile → replay 3-sao, giữ chân mạnh nhất trong nhóm feature.

## Acceptance criteria
- [ ] Nổ nhóm đạt ngưỡng → 1 ô trong vùng biến thành power tile (giữ trên bàn).
- [ ] Tap power tile → kích hoạt hiệu ứng tương ứng (dùng anim pop + hạt).
- [ ] Kích 2 power tile cạnh nhau → hiệu ứng cộng hưởng (stretch goal).
- [ ] Power tile rơi/collapse như ô thường; hiển thị khác biệt rõ (icon + glow).
- [ ] Unit test: ngưỡng sinh đúng loại; kích hoạt xoá đúng vùng.

## Subtasks (gợi ý file)
1. `lib/logic/`: model tile mở rộng — ô mang `kind` (normal/line/bomb/rainbow).
   Đổi `colorGrid` sang grid có kind, hoặc grid phụ `powerGrid`.
2. `lib/game/pop_star_game.dart`: sau `_tryPop`, nếu size≥ngưỡng → set power tile tại
   1 ô (vd ô được tap). `handleTap` phân nhánh: tap power tile → activate.
3. `lib/game/block_component.dart`: render biến thể power (icon rocket/bom/rainbow + glow).
4. Cân bằng điểm + achievability sim lại.
5. Test: `test/logic/power_tiles_test.dart`, `test/presentation/...`.

## Ghi chú kỹ thuật
Task nặng — CHẺ trước khi làm: (5a) line-clear only, (5b) bomb, (5c) rainbow, (5d)
combo cộng hưởng. Đụng core `pop_star_game` → không song song với F6.

DoD chung: `../README.md`.
