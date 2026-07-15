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
- [x] Nổ nhóm đạt ngưỡng → 1 ô trong vùng biến thành power tile (giữ trên bàn).
- [x] Tap power tile → kích hoạt hiệu ứng tương ứng (dùng anim pop + hạt).
- [ ] Kích 2 power tile cạnh nhau → hiệu ứng cộng hưởng (stretch goal). ⏸️
      **Deferred (2026-07-14)** — tự doc đã đánh dấu stretch goal + "chẻ nhỏ
      trước khi làm (5a/5b/5c/5d)"; 5a/5b/5c (line/bomb/rainbow) đã xong,
      5d (cộng hưởng) chưa có behavior spec rõ (2 loại nào cạnh nhau → hiệu
      ứng gì cụ thể?) — cần quyết định thiết kế trước khi code, không tự
      suy đoán. Để ngỏ theo YAGNI, làm khi có yêu cầu + spec cụ thể.
- [x] Power tile rơi/collapse như ô thường; hiển thị khác biệt rõ (icon + glow).
- [x] Unit test: ngưỡng sinh đúng loại; kích hoạt xoá đúng vùng.

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

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `lib/logic/power_tile.dart` (ngưỡng→kind), `pop_star_game.dart`
(`_tryPop`/`handleTap`/`_activatePowerTile`/`_clearAndCollapse`), `block_component.dart`
(icon+glow render), test `test/logic/power_tile_test.dart` +
`test/widget/power_tile_test.dart`/`power_tile_bomb_test.dart`/`power_tile_rainbow_test.dart`.
Mục "cộng hưởng 2 power tile cạnh nhau" (stretch goal) không thấy trong code — để ngỏ.
