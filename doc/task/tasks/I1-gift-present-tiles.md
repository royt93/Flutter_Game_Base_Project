# I1 — Gift/present tiles

**Epic:** Features · **SP:** 5 · **Pri:** Should · **Deps:** F6 (tái dùng khung obstacle/objective)

## Mục tiêu
Ô quà (gift tile) không thuộc nhóm màu — không nổ khi tap trực tiếp. Đưa được
xuống hàng đáy (qua gravity, không cần thao tác riêng) N lần liên tiếp không bị
kẹt thì tự mở, cộng thưởng ngẫu nhiên (coin/booster).

## Vì sao
Thêm mục tiêu "dọn đường cho quà rơi" — khác hẳn objective điểm/obstacle hiện
có (F6), tạo puzzle mới mà không cần cơ chế tap mới.

## Acceptance criteria
- [x] Ô gift render riêng, không thuộc `colorGrid` nhóm màu (encoding tương tự
      obstacle — giá trị đặc biệt, không lẫn màu thường).
- [x] Gift chạm hàng đáy sau gravity → tự mở, cộng coin/booster ngẫu nhiên (bảng
      trọng số cố định, không cần seed đặc biệt).
- [x] Gift bị kẹt (không rơi thêm do vật cản) vẫn giữ nguyên, không mất, không lỗi.
- [x] Level định nghĩa được objective "mở K ô quà".
- [x] Unit test: gift rơi tới đáy tự mở; đếm objective đúng.

## Rà soát checkbox (2026-07-13)
- `lib/logic/gift_tile.dart`: `giftTileValue = -1000` (giá trị âm cố định,
  cùng pattern obstacle), `openGiftsAtBottomRow`, `pickGiftReward`/
  `giftRewardPool` (bảng trọng số cố định).
- `pop_detector.dart`: loại trừ giá trị âm (gồm gift) khỏi
  `findConnectedGroup` qua `color < 0`.
- `lib/game/pop_star_game.dart:197,265-268`: `_placeGiftsIfNeeded` (chỉ spawn
  khi objective `openGift`); sau gravity gọi mở gift + `grantGiftReward`
  (dòng ~1097). `block_component.dart:272-276,553` `_renderGift` vẽ riêng.
- `lib/data/levels.dart:19,56-57`: `ObjectiveType.openGift` +
  `LevelObjective.openGift(target)`. `game_controller.dart:64-65` đếm objective
  qua `grid.expand(...).where((v) => v == giftTileValue).length`.
- Test: `test/logic/gift_tile_test.dart` — gift ở đáy tự mở trả về cột đúng;
  gift chưa tới đáy giữ nguyên (không mất/lỗi khi kẹt).

## Subtasks (gợi ý file)
1. `lib/logic/obstacle.dart` (hoặc file mới `gift_tile.dart` cùng pattern
   encoding): giá trị đặc biệt cho gift, không tham gia `findConnectedGroup`.
2. `lib/data/levels.dart`: objective `giftCount` + tham số rải gift.
3. `lib/game/pop_star_game.dart`: sau `applyGravityAndCollapse`, kiểm tra gift ở
   hàng đáy → mở + cộng thưởng.
4. `lib/presentation/controllers/game_controller.dart`: theo dõi objective.

## Ghi chú kỹ thuật
Tái dùng đúng pattern negative-value-encoding của `obstacle.dart` cho nhất
quán, không tạo hệ thống song song.

DoD chung: `../README.md`.
