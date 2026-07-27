/// I46: sentinel âm cố định cho Wildcard Tile trong colorGrid — khớp với MỌI
/// màu khi tính nhóm liền kề (xem `pop_detector.findConnectedGroup`). Dải
/// riêng, không trùng obstacle (-1..-9), gift (`giftTileValue` = -1000),
/// Countdown Lock (`countdownLockIdBase` = -1500), boss (mọi giá trị
/// <= `bossTileIdBase` = -2000).
const wildcardTileValue = -500;

bool isWildcardTileValue(int? value) => value == wildcardTileValue;
