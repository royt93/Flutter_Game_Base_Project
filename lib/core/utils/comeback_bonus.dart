/// I10: đã vắng >=3 ngày kể từ lần mở trước ([lastOpenEpochDay], -1 nếu chưa
/// từng mở) → cần tặng quà comeback.
bool needsComebackBonus({
  required int lastOpenEpochDay,
  required int todayEpochDay,
}) => lastOpenEpochDay >= 0 && todayEpochDay - lastOpenEpochDay >= 3;
