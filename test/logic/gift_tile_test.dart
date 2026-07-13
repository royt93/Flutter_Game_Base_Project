import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';

void main() {
  group('openGiftsAtBottomRow', () {
    test('gift ở hàng đáy tự mở thành null, trả về đúng cột', () {
      final grid = <List<int?>>[
        [0, giftTileValue],
        [1, giftTileValue],
      ];
      final opened = openGiftsAtBottomRow(grid);
      expect(opened, [1]);
      expect(grid[1][1], isNull);
    });

    test('gift chưa tới hàng đáy thì giữ nguyên, không mở', () {
      final grid = [
        [giftTileValue, 0],
        [1, 0],
      ];
      final opened = openGiftsAtBottomRow(grid);
      expect(opened, isEmpty);
      expect(grid[0][0], giftTileValue);
    });
  });

  test('pickGiftReward luôn trả về phần thưởng trong bảng trọng số', () {
    final reward = pickGiftReward(Random(1));
    expect(
      giftRewardPool.any(
        (r) => r.type == reward.type && r.amount == reward.amount,
      ),
      isTrue,
    );
  });
}
