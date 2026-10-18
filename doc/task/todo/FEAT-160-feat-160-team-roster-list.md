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
- Danh sách `TeamMemberItem` do caller cung cấp: id, name, role (`TeamRole.leader | elder | member`), avatar, trophies/contribution, online status (online hoặc last seen text).
- Role badges màu chuẩn NeonTheme, tự căn chỉnh độ cao và hỗ trợ textScale.
- Action callbacks: `onMemberTap(memberId)`, `onPromote(memberId)?`, `onKick(memberId)?`.
- Lazy `ListView.builder` với empty state và header thống kê (tổng thành viên / giới hạn max).
- Presentation-only: caller sở hữu danh sách, phân quyền và mutation.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate IDs duy nhất, tên không rỗng, giới hạn maxMembers > 0 và maxMembers >= members.length (`team_roster_list_test.dart`).
- [ ] **Widget test**: Hiển thị roles, contribution, online status, callback tap/promote/kick, empty state, semantics và textScale 2.0.
- [ ] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) tap member và kick/promote callback qua caller seam; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` baseline/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844. Android tap-target và labeled-target guidelines bật.
- [ ] **Interruption test**: Scroll danh sách 100 thành viên, thay đổi role/status giữa lúc scroll, unmount/remount không throw.
- [ ] **Network conditioning test**: N/A — roster sync thuộc caller.
- [ ] **Memory leak & profiling test**: Pixel 7 Pro debug 5 chu kỳ mount/scroll 100 thành viên/unmount, kiểm tra ScrollPosition disposal và MemoryWatchdog 0 orphan mới.
- [ ] **Frame rate / Jank test**: Pixel 7 Pro profile `flutter drive --profile` ghi FrameTiming p50/p95/p99 và slow frame %.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] `ListView.builder` lazy rendering, avatar chỉ build khi cell xuất hiện.
- [ ] Ghi số liệu đo đạc thực tế từ thiết bị, không tự suy đoán 60 FPS.
