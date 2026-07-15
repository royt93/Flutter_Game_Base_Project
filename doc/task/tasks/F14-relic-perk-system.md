# F14 — Relic/Perk system (không pay-to-win)

**Epic:** Features · **SP:** 13 (chẻ nhỏ) · **Pri:** Could · **Deps:** F4 (world structure), F7 (star road mốc)

## Mục tiêu
Perk vĩnh viễn mở khoá khi hoàn thành world (không mua bằng tiền thật/coin),
tối đa 2 perk active cùng lúc, chọn qua màn hình riêng trước khi vào level.

## Vì sao
Ý tưởng độc quyền được chọn, với ràng buộc rõ: KHÔNG pay-to-win, KHÔNG IAP —
chỉ mở khoá qua tiến độ chơi, giữ đúng loại trừ Option D.

## Acceptance criteria
- [x] Danh sách perk cố định (vd: +1 undo mỗi màn, hiện trước 1 nước đi gợi ý,
      +10% coin màn đó...) — hiệu ứng nhẹ, không đổi target/luật thắng.
- [x] Mở khoá 1 perk khi hoàn thành 1 world (dùng lại mốc world đã có ở F4).
- [x] Tối đa 2 perk active cùng lúc, chọn/đổi ở màn hình riêng trước khi vào
      level (không đổi giữa chừng ván).
- [x] Perk KHÔNG mua được bằng coin hay tiền thật — chỉ mở khoá qua tiến độ.
- [x] Unit test: mở khoá đúng theo world hoàn thành; giới hạn 2 active đúng.

## Subtasks (gợi ý file)
1. `lib/data/` — danh sách perk cố định + world mốc mở khoá.
2. `lib/presentation/controllers/game_controller.dart`: `unlockedPerks`,
   `activePerks` (max 2), áp dụng hiệu ứng vào `startLevel`/`checkEnd`.
3. Màn hình chọn perk mới (trước level select hoặc trong đó).
4. Áp hiệu ứng vào chỗ tương ứng (`useUndo` cộng thêm, `_checkEnd` cộng coin...).

## Ghi chú kỹ thuật
CHẺ: (a) data + unlock theo world; (b) chọn/giới hạn 2 active + UI; (c) áp
hiệu ứng vào từng chỗ chơi thực tế. Danh sách hiệu ứng giữ nhỏ, không đổi luật
thắng-thua cốt lõi (chỉ tiện ích/hệ số nhẹ).

DoD chung: `../README.md`.

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `lib/data/perks.dart` (`PerkEffect` enum, `kPerks` 3 perk cố định,
`worldsCompleted`/`unlockedPerks` dùng `kWorlds` từ F4, không có đường mua bằng coin),
`game_controller.dart` (`togglePerkSelection` giới hạn 2, hiệu ứng ở `_freeUndoLeft`/
coin bonus), `perks_screen.dart` (màn chọn riêng), test `test/data/perks_test.dart`.
