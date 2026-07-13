import 'dart:math';

/// I1: ô quà (gift) mã hoá bằng 1 giá trị âm cố định trong colorGrid — khác
/// obstacle (`obstacle.dart`, âm = độ bền, phạm vi nhỏ -1..-vài) nên phải
/// dùng hằng số cách xa hẳn và loại trừ tường minh khỏi
/// `chipAdjacentObstacles` (không thì bị hiểu nhầm thành obstacle rất bền).
/// Không thuộc nhóm màu — `pop_detector` đã loại mọi giá trị < 0 khỏi
/// flood-fill.
const int giftTileValue = -1000;

/// Ô quà rơi tới hàng đáy (sau gravity) → tự mở (thành ô trống). Trả về cột
/// của các ô vừa mở, để caller gỡ block hiển thị + cộng thưởng. Mutates
/// [grid] in place.
List<int> openGiftsAtBottomRow(List<List<int?>> grid) {
  final rows = grid.length;
  if (rows == 0) return const [];
  final bottom = rows - 1;
  final opened = <int>[];
  for (var c = 0; c < grid[bottom].length; c++) {
    if (grid[bottom][c] == giftTileValue) {
      grid[bottom][c] = null;
      opened.add(c);
    }
  }
  return opened;
}

/// Thưởng ngẫu nhiên khi mở gift — bảng trọng số cố định, không cần seed
/// đặc biệt (khác spin/leaderboard vốn cần công bằng theo ngày).
class GiftReward {
  const GiftReward(this.type, this.amount);
  final String type; // 'coins' | 'bomb' | 'shuffle' | 'undo'
  final int amount;
}

const List<GiftReward> giftRewardPool = [
  GiftReward('coins', 50),
  GiftReward('coins', 100),
  GiftReward('coins', 150),
  GiftReward('bomb', 1),
  GiftReward('shuffle', 1),
  GiftReward('undo', 1),
];

GiftReward pickGiftReward(Random rng) =>
    giftRewardPool[rng.nextInt(giftRewardPool.length)];
