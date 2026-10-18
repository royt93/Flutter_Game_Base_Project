---
id: FEAT-160
title: TeamRosterList — Danh sách thành viên team/clan kèm role, đóng góp và online status
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Social & Team Meta UI (Wave 15)
---

## Vì sao cần
Game casual có tính năng team/clan cần hiển thị danh sách thành viên với vai trò (Leader/Elder/Member), điểm đóng góp tuần và trạng thái hoạt động. UI cần lazy rendering cho clan đông (50+ thành viên), xử lý caller-owned actions như tap profile, promote, kick mà không tự quản lý permission mạng.

## Đề xuất phạm vi
Widget `TeamRosterList` hiển thị:
- Danh sách `TeamMemberItem` do caller cung cấp: id, name, role (`TeamRole.leader | elder | member`), avatar, trophies/contribution, online status (online hoặc last seen text), `isSelf`.
- Role badges màu chuẩn NeonTheme, tự căn chỉnh độ cao và hỗ trợ textScale.
- Action callbacks: `onMemberTap(memberId)`, `onPromote(memberId)?`, `onKick(memberId)?`.
- Hỗ trợ cờ `expand: bool` (mặc định false): khi true cho phép chiếm trọn chiều cao màn hình độc lập (Expanded); khi false co giãn an toàn theo số dòng (clamped bởi maxListHeight).
- Header thống kê (tổng thành viên / giới hạn maxMembers).
- Presentation-only: caller sở hữu danh sách, phân quyền và mutation.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate IDs duy nhất, tên không rỗng, trophies >= 0, giới hạn maxMembers > 0 và maxMembers >= members.length (`team_roster_list_test.dart`).
- [x] **Widget test**: Hiển thị roles, contribution, online status, callback tap/promote/kick, empty state, cờ `expand`, semantics và textScale 2.0 trên viewport 320dp không overflow.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) tap member và kick/promote callback qua caller seam (`app_boot_test.dart`); pass, không dùng simulator.
- [x] **Golden test**: 14 PNG baseline comparisons cho normal và empty trên light/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844. Android tap-target tối thiểu 48dp cho các nút hành động.
- [x] **Interruption test**: Test catalog 100 thành viên xác nhận lazy rendering, fling khi đang scroll, unmount/remount không throw.
- [x] **Network conditioning test**: N/A — roster sync thuộc caller.
- [x] **Memory leak & profiling test**: Pixel 7 Pro debug (`team_roster_perf_test.dart`, 2026-10-18): 100 thành viên, 5 chu kỳ mount/scroll/unmount, 5 `ScrollPosition` đã dispose (kiểm tra trực tiếp `ChangeNotifier.debugAssertNotDisposed`), MemoryWatchdog có 0 orphan mới. RSS sau mỗi unmount: 631.431.168 / 646.119.424 / 664.961.024 / 686.272.512 / 665.927.680 byte.
- [x] **Frame rate / Jank test**: Pixel 7 Pro profile qua `flutter drive --profile` (`team_roster_perf_test.dart`, 2026-10-18): 3.308 frames, totalSpan p50/p95/p99 = 6.305/10.571/13.640ms, max(build,raster) p50/p95/p99 = 4.039/5.451/8.753ms, slow-frame 0,091%, jank 3 với ngưỡng max(build,raster) > 16.667ms. Mẫu là scroll 100 thành viên 32 giây sau warm-up. Đây là engine FrameTiming, không phải số missed-vsync từ compositor.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] `ListView.separated` lazy rendering; avatar widget chỉ được gắn vào cell đang build.
- [x] Sustained benchmark đã đo cửa sổ 32 giây trên Pixel 7 Pro: 3/3.308 frames vượt budget 60Hz, p99 engine frame latency 13.640ms. Không cam kết 60 FPS cho thiết bị yếu hơn hay thermal soak kéo dài.

## Chạy lại
```bash
flutter test test/widget/common/team_roster_list_test.dart test/widget/goldens/team_roster_list_golden_test.dart
cd example
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name "FEAT-160"
flutter test integration_test/team_roster_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
flutter drive --profile --driver integration_test/profile_driver.dart --target integration_test/team_roster_perf_test.dart -d <device-id> --dart-define=E2E_TEST=true
```
