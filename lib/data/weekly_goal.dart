/// I50 Weekly Goal Card: mục tiêu tuần cố định 300 gem, cộng dồn xuyên suốt
/// mọi mode (campaign + side-mode), reset về 0 khi sang tuần mới
/// (`epochDay ~/ 7` đổi giá trị).
const int weeklyGoalTarget = 300;

/// Tuần hiện tại theo [epochDay] — cùng convention `epochDay ~/ 7` với
/// `currentSeasonIndex` (`todayEpochDay() ~/ seasonLengthDays`).
int weekIndexForEpochDay(int epochDay) => epochDay ~/ 7;

/// Tiến độ mục tiêu tuần sau khi xử lý reset-nếu-sang-tuần-mới. Tuần không
/// đổi (`currentWeek == previousWeek`) giữ nguyên [previousProgress]; sang
/// tuần mới thì reset về 0 (bỏ tiến độ tuần cũ, không cộng dồn qua tuần).
int weeklyGoalProgressForWeek({
  required int previousWeek,
  required int currentWeek,
  required int previousProgress,
}) => currentWeek == previousWeek ? previousProgress : 0;
