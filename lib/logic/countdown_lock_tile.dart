import 'boss_tile.dart';

/// I45: id riêng cho Countdown Lock tile, mã hoá âm trong colorGrid giống
/// obstacle/gift/boss — nằm giữa dải gift (`giftTileValue` = -1000) và dải
/// boss (mọi giá trị <= [bossTileIdBase] = -2000, không giới hạn trên) để
/// không đụng nhau. Mỗi màn tối đa 1 instance nên không cần id giảm dần.
const countdownLockIdBase = -1500;

/// Số lượt tap hợp lệ ban đầu trước khi Countdown Lock tự chuyển thành
/// obstacle thường.
const countdownLockStartValue = 5;

bool isCountdownLockId(int? value) =>
    value != null && value <= countdownLockIdBase && value > bossTileIdBase;

/// Giảm 1 độ đếm ngược mọi Countdown Lock đang có trên bàn — gọi mỗi lượt
/// tap hợp lệ, bất kể tap có trúng tile này hay không (khác obstacle/boss chỉ
/// giảm khi bị pop-nhóm-màu kề bên chip). Trả về id vừa hết giờ (0) để caller
/// chuyển ô đó thành obstacle thường, hoặc null nếu chưa ô nào hết. Mutates
/// [countdownRemaining] in place.
int? tickCountdownLockTiles(Map<int, int> countdownRemaining) {
  int? expired;
  for (final id in countdownRemaining.keys.toList()) {
    final next = countdownRemaining[id]! - 1;
    if (next <= 0) {
      countdownRemaining.remove(id);
      expired = id;
    } else {
      countdownRemaining[id] = next;
    }
  }
  return expired;
}
