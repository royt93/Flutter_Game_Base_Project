import '../storage_service.dart';

/// Đồng hồ "không bao giờ lùi" — một monotonic day/ms clock dùng chung cho
/// mọi hệ thưởng theo thời gian (daily reward, streak, mùa...). Một helper
/// độc lập ở đây, thay vì logic nằm rải rác trong từng nơi cần nó, để mọi
/// hệ thưởng theo ngày đều đi qua cùng một lớp bảo vệ.
///
/// **Chống được gì:** vòng lặp "chỉnh đồng hồ tiến → nhận thưởng → chỉnh lùi
/// lại → lặp". Sau khi kẹp, chỉnh lùi không có tác dụng, nên mỗi lần gian lận
/// đốt luôn thời gian tương lai thật của người chơi (mất mốc daily/streak/mùa
/// tương ứng). Đó là mức bảo vệ tối đa mà client làm được khi không có nguồn
/// thời gian tin cậy từ server.
///
/// **KHÔNG chống được:** nhảy đồng hồ tiến một chiều. Vì vậy **đừng** áp lớp
/// kẹp này cho những thứ mà "ở lại tương lai" chính là điều người gian lận
/// muốn — ví dụ một sự kiện cuối tuần: đặt máy sang thứ Bảy rồi ở nguyên đó
/// là đã đạt mục đích, và kẹp monotonic còn khiến trạng thái đó thành vĩnh
/// viễn, tức là làm mọi thứ tệ hơn.

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
