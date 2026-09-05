/// Thông tin ứng dụng (hiển thị ở Home / About).
const String kAppName = 'Roy Project Base Game';
const String kCopyright = '© SAIGON PHANTOM LABS';

/// Version + build number hiển thị — đọc TỰ ĐỘNG từ pubspec lúc khởi chạy (xem
/// `loadAppVersion` trong `main.dart`) nên không bao giờ lệch với `pubspec.yaml`.
/// Giá trị mặc định chỉ là fallback nếu package_info chưa kịp nạp (vd test widget).
String kAppVersion = '2026.06.15';
String kAppBuildNumber = '20260615';

/// Package/bundle id — đọc TỰ ĐỘNG từ `loadAppVersion` giống [kAppVersion],
/// dùng cho link store (rate/share) thay vì hardcode chuỗi cố định.
String kPackageName = 'com.galaxyjoy.roybasegame';
