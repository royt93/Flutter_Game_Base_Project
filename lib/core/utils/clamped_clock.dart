import '../storage_service.dart';

/// X22: đồng hồ "không bao giờ lùi" dùng chung cho mọi hệ thưởng theo thời
/// gian. Trước đây logic này chỉ nằm trong `GameController.todayEpochDay()`,
/// nên hệ nào không cầm được controller (vd `RaidBossController`) lại tự viết
/// `DateTime.now()` thô và mất lớp bảo vệ.
///
/// **Chống được gì:** vòng lặp "chỉnh đồng hồ tiến → nhận thưởng → chỉnh lùi
/// lại → lặp". Sau khi kẹp, chỉnh lùi không có tác dụng, nên mỗi lần gian lận
/// đốt luôn thời gian tương lai thật của người chơi (mất mốc daily/streak/mùa
/// tương ứng). Đó là mức bảo vệ tối đa mà client làm được khi không có nguồn
/// thời gian tin cậy từ server.
///
/// **KHÔNG chống được:** nhảy đồng hồ tiến một chiều. Vì vậy **đừng** áp lớp
/// kẹp này cho những thứ mà "ở lại tương lai" chính là điều người gian lận
/// muốn — ví dụ sự kiện cuối tuần (`isWeekendEvent`): đặt máy sang thứ Bảy rồi
/// ở nguyên đó là đã đạt mục đích, và kẹp monotonic còn khiến trạng thái đó
/// thành vĩnh viễn, tức là làm mọi thứ tệ hơn. Xem [[X22]].

/// Mốc mili-giây hiện tại, kẹp không lùi dưới giá trị lớn nhất từng thấy.
int nowMsClamped() {
  final current = DateTime.now().toUtc().millisecondsSinceEpoch;
  final maxSeen = StorageService.to.getInt(StorageKeys.maxMsSeen);
  if (current > maxSeen) {
    StorageService.to.setInt(StorageKeys.maxMsSeen, current);
    return current;
  }
  return maxSeen;
}

/// Số ngày kể từ epoch (UTC), kẹp không lùi dưới mốc lớn nhất từng thấy.
int todayEpochDayClamped() {
  final current = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
  final maxSeen = StorageService.to.getInt(StorageKeys.maxEpochDaySeen);
  if (current > maxSeen) {
    StorageService.to.setInt(StorageKeys.maxEpochDaySeen, current);
    return current;
  }
  return maxSeen;
}
