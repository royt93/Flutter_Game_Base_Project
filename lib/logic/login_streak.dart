/// I48 Login Streak Calendar — tính streak điểm danh kế tiếp theo epoch-day.
/// Cùng ngày → giữ nguyên (đã điểm danh); cách 1 ngày → +1; cách ≥2 ngày → reset về 1.
int nextLoginStreak({
  required int previousEpochDay,
  required int todayEpochDay,
  required int previousStreak,
}) {
  final gap = todayEpochDay - previousEpochDay;
  if (gap <= 0) return previousStreak;
  if (gap == 1) return previousStreak + 1;
  return 1;
}
