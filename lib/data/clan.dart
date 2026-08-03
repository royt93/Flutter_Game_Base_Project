import 'dart:math';

/// I66 Clan Lite: 1 clan cố định duy nhất (không chọn/tạo, không backend) —
/// người chơi + [kClanMemberNames] NPC tĩnh. Mục tiêu pool chung theo tuần
/// (dùng chung `weekIndexForEpochDay` từ `weekly_goal.dart` với I50 Weekly
/// Goal — không định nghĩa lại ở đây).
const int clanGoalTarget = 2000;

/// 6 thành viên NPC cố định của clan.
const List<String> kClanMemberNames = [
  'NovaBlaze',
  'PixelFox',
  'GemGuru',
  'ComboKid',
  'StarChaser',
  'LuckyPop',
];

/// Đóng góp giả lập của NPC [botIndex] trong tuần [weekIndex] — seeded nên
/// ổn định cho mọi người chơi, đổi mỗi tuần. Khoảng 150-399.
int clanBotContributionForWeek(int weekIndex, int botIndex) =>
    Random(weekIndex * 97 + botIndex).nextInt(250) + 150;

/// Tổng đóng góp cả clan (NPC + người chơi) trong tuần [weekIndex].
int clanPoolTotal(int weekIndex, int playerContribution) {
  var total = playerContribution;
  for (var i = 0; i < kClanMemberNames.length; i++) {
    total += clanBotContributionForWeek(weekIndex, i);
  }
  return total;
}
