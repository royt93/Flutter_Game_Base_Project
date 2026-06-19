// Tiện ích định dạng dùng chung.

import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Định dạng [Duration] thành "mm:ss" (phút:giây, mỗi phần 2 chữ số).
/// Dùng cho đếm ngược hồi mạng ở Home / Level Select / World Map.
String fmtDur(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Thời gian còn lại tới **nửa đêm GIỜ MÁY** sau [daysLeft] ngày kể từ hôm nay.
///
/// Dùng cho đếm ngược kết thúc Mùa / Giải đấu tuần. Mốc kết thúc dựng từ CÁC
/// THÀNH PHẦN NGÀY ĐỊA PHƯƠNG (`DateTime(year, month, day + daysLeft)`) — khớp
/// cách `todayEpochDay` tính (cũng theo local date). Trước đây mốc kết thúc bị
/// tái dựng bằng UTC midnight (`endDay * 86400000`) trong khi epoch-day lại theo
/// local → lệch đúng offset múi giờ (UTC+7 → countdown nhảy 00:00:00 sớm 7 giờ).
/// Dart tự chuẩn hoá `day` tràn (vd 35 → tháng kế).
Duration durationToLocalMidnight(DateTime now, int daysLeft) {
  final end = DateTime(now.year, now.month, now.day + daysLeft);
  final ms = end.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
  return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
}

/// Định dạng số nguyên lớn (xu, điểm, giá, máu boss…) với DẤU PHÂN TÁCH HÀNG
/// NGHÌN theo NGÔN NGỮ hiện tại: vi → "10.000", en → "10,000", de → "10.000"…
/// Dùng [NumberFormat] (intl) theo `Get.locale`; nếu locale lạ/chưa có dữ liệu
/// thì fallback nhóm thủ công bằng dấu '.' (kiểu Việt) để KHÔNG bao giờ ném lỗi.
String fmtNum(int n) {
  try {
    return NumberFormat.decimalPattern(Get.locale?.languageCode ?? 'en')
        .format(n);
  } catch (_) {
    final neg = n < 0;
    final digits = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return neg ? '-$buf' : buf.toString();
  }
}
