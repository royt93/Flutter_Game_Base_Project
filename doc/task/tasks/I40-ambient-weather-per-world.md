# I40 — Ambient Weather theo World Theme

**Epic:** Cảm giác/A-V · **SP:** 5 · **Pri:** Could · **Deps:** `I14`, `I16` (đã xong)

## Mục tiêu
Thêm 1 lớp hiệu ứng thời tiết nhẹ (particle rơi chậm phía sau board, không
che gameplay) khác nhau theo từng `GameWorld` — ví dụ world băng
(`world_path_name_7`, icon `ac_unit_rounded`) có tuyết rơi, world lửa
(`world_path_name_2`/`8`) có tia lửa bay lên, world nước (`world_path_name_3`/`9`)
có bong bóng nổi. World cuối (aurora, `I16`) giữ nguyên, không chồng thêm
weather layer (tránh rối mắt).

## Vì sao
`I14-theme-per-world.md` mới đổi tông màu nền theo world, `I16` chỉ áp cho
world cuối cùng — 9 world còn lại (2-10) có màu khác nhau nhưng cùng 1 kiểu
chuyển động nền tĩnh. Weather particle là lớp bổ sung rẻ (particle system đã
có sẵn từ pop burst/confetti) tăng bản sắc từng world mà không cần shader mới
cho mỗi world.

## Acceptance criteria
- [ ] `lib/presentation/widgets/ambient_weather_layer.dart` (mới): widget
      nhận `GameWorld world`, chọn 1 trong ≤4 kiểu particle cố định dựa theo
      `world.icon` hoặc thêm field `WeatherKind weather` vào `GameWorld`
      (enum `none, snow, spark, bubble` — mặc định `none` cho world chưa
      gán). Dùng `CustomPainter`/particle list đơn giản (vài chục hạt di
      chuyển chậm, loop vô hạn) — KHÔNG dùng shader `.frag` mới (khác `I16`,
      đây chỉ cần particle rẻ, không cần hiệu ứng phức tạp).
- [ ] `GameWorld` (`lib/data/worlds.dart`): thêm field optional
      `WeatherKind weather = WeatherKind.none`, gán cho world 2 (lửa → spark),
      3 (nước → bubble), 7 (băng → snow) làm ví dụ tối thiểu — có thể mở rộng
      thêm world khác nếu thời gian cho phép, nhưng tối thiểu 3 world có
      weather khác `none` để chứng minh tính năng hoạt động.
- [ ] Gắn `AmbientWeatherLayer` vào `NeonBg`/`GameScreen` background stack
      (cùng chỗ `AuroraBgLayer` được gắn ở `neon_bg.dart`/`game_screen.dart`),
      chỉ hiện khi `world.weather != WeatherKind.none` và world đó không phải
      world cuối (không chồng lên aurora).
- [ ] Tôn trọng `reduce_motion` — nếu bật, `AmbientWeatherLayer` không
      `.repeat()` animation (particle đứng yên hoặc ẩn hẳn), theo đúng pattern
      đã áp dụng cho `star_mascot`/`pulse_glow`/`level_select_screen._flowCtrl`
      (xem commit `28ccb94`).
- [ ] i18n: không cần (không có text).
- [ ] Widget test: `AmbientWeatherLayer` render không lỗi với từng
      `WeatherKind`; `weather == none` → không build particle nào (hoặc trả
      `SizedBox.shrink()`); reduce-motion bật → controller không chạy
      `.repeat()` (kiểm tra qua `AnimationController.isAnimating == false`
      hoặc tương đương).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `AuroraBgLayer` (`lib/presentation/widgets/aurora_bg_layer.dart`) đã có sẵn
  pattern gắn 1 layer phụ lên `NeonBg` (`aurora: bool` param, `neon_bg.dart`
  dòng ~108) — theo cùng convention (thêm param mới thay vì sửa cấu trúc
  `NeonBg` hiện có).
- `kWorlds` (`lib/data/worlds.dart`) là `const List` — thêm field mới vào
  `GameWorld` phải cập nhật TẤT CẢ 11 khai báo const hiện có (dù chỉ 3 world
  cần giá trị khác `none`, 8 world còn lại vẫn phải khai báo tường minh hoặc
  dùng default value để không phá vỡ các entry cũ).
- Đừng nhầm phạm vi với `I16` (aurora shader, world cuối, đã xong) — I40
  không sửa `AuroraBgLayer`, chỉ thêm layer song song cho các world khác.

DoD chung: `../README.md`.
