import 'levels.dart';

/// I38: id level campaign được chọn làm "Level tuần này" — deterministic
/// theo tuần (`epochWeek`, xem `weekIndexForEpochDay` ở `weekly_goal.dart`),
/// không dùng `Random()` để mọi người chơi cùng tuần thấy cùng level.
int featuredLevelIdForWeek(int epochWeek) => epochWeek % kLevelCount + 1;
