// Tiện ích định dạng dùng chung.

/// Định dạng [Duration] thành "mm:ss" (phút:giây, mỗi phần 2 chữ số).
/// Dùng cho đếm ngược hồi mạng ở Home / Level Select / World Map.
String fmtDur(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
