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

/// I55: bản có "Streak Freeze" — lỡ đúng 1 ngày (gap == 2) mà còn ít nhất 1
/// token thì giữ nguyên streak thay vì reset (token bị tiêu, `usedFreeze`
/// báo cho caller trừ [StorageKeys.streakFreezeCount]). gap >= 3 hoặc hết
/// token ở gap == 2 vẫn reset về 1 như hành vi gốc.
({int streak, bool usedFreeze}) nextLoginStreakWithFreeze({
  required int previousEpochDay,
  required int todayEpochDay,
  required int previousStreak,
  required bool hasFreezeAvailable,
}) {
  final gap = todayEpochDay - previousEpochDay;
  if (gap <= 0) return (streak: previousStreak, usedFreeze: false);
  if (gap == 1) return (streak: previousStreak + 1, usedFreeze: false);
  if (gap == 2 && hasFreezeAvailable) {
    return (streak: previousStreak, usedFreeze: true);
  }
  return (streak: 1, usedFreeze: false);
}
