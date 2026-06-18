---
id: w14-collection-piggybank
title: Meta — Collection/Album + Piggy Bank
wave: 14
status: done
owner: claude
---

# Collection/Album + Piggy Bank (heo đất)

## Collection / Album
Sổ sưu tập gem/sticker mở khoá qua chơi. Mỗi màn thắng → +điểm sưu tập; đạt mốc
mở 1 ô album (đổi xu/booster khi mở). Coin-sink nhẹ + động lực sưu tập.
- `lib/data/collection.dart` (items + mốc). `CollectionController` (permanent,
  resetState, maybe). `CollectionScreen` (lưới ô, NeonAppBar/NeonBg/CoinChip).
- addWin(stars) gọi từ GameScreenController (như Season).

## Piggy Bank (heo đất)
Heo tích xu: mỗi màn thắng bỏ ống 1 ít xu (cap). Khi heo đầy (mốc) → đập nhận
toàn bộ (đập có phí nhỏ hoặc miễn phí khi đầy). Coin-sink/giữ chân, hook IAP sau.
- `PiggyController` (permanent). `PiggyScreen` hoặc overlay. Nút Home.

## Việc
- 2 controller + screen + data + nút Home (hàng meta). Đăng ký Get.put permanent.
- resetProgress gọi resetState + xoá key. i18n en+vi.

## Test
- collection cộng điểm + mở mốc; piggy tích + đập nhận; persist + reset.
