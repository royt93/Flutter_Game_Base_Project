# I53 — Home Screen Theme Pack

**Epic:** Cảm giác/A-V (cosmetic độc quyền) · **SP:** 3 · **Pri:** Could
· **Deps:** không

## Mục tiêu

Nền gradient của `home_screen.dart` tự đổi màu theo world cao nhất người
chơi đã unlock (`kWorlds`/`worldForLevel`), thay vì 1 gradient tĩnh cố
định như hiện tại. Mỗi khi `unlockedLevel` tăng qua ngưỡng world mới,
home screen chuyển dần sang màu chủ đạo của world đó (dùng đúng bảng màu
`GameWorld.color` đã có sẵn cho 11 world).

## Vì sao

Đây là cosmetic **tự động, không cần unlock/chọn thủ công** — khác I51/
I52 (người chơi tự chọn). Ý tưởng là biến tiến trình campaign (vốn đã có
sẵn, không cần thêm hệ thống mới) thành 1 phần thưởng thị giác thụ động,
chi phí implement thấp nhất trong cả 3 ý cosmetic vì tái dùng 100% dữ
liệu `kWorlds` đã tồn tại, không cần bảng unlock/storage key riêng.

## Acceptance criteria

- [ ] `home_screen.dart`: nền hiện tại (`NeonBg` hoặc gradient trực tiếp
  trong widget) đổi thành gradient phối màu theo
  `worldForLevel(unlockedLevel.value).color` (world cao nhất đã unlock,
  suy từ `GameController.unlockedLevel` — không cần field/state mới).
- [ ] Đổi world → đổi gradient có animation chuyển màu mượt (dùng
  `AnimatedContainer`/`TweenAnimationBuilder`, không snap tức thời — nhất
  quán với hướng "loại bỏ snap tức thời" đã áp dụng trước đó trong dự án
  cho booster/dialog).
- [ ] World 11 (world cuối, index 10) giữ lại hiệu ứng `WeatherKind`
  hiện có của world đó nếu có (không thay đổi hệ thống weather, chỉ thêm
  gradient nền theo màu world).
- [ ] Không ảnh hưởng độ tương phản/độ đọc được của text trên home
  screen (kiểm tra nhanh bằng mắt qua build_run_sim sau khi cài đặt —
  không cần thước đo contrast tự động).
- [ ] Widget test: `home_screen_test.dart` (hoặc file tương đương hiện
  có) — verify gradient áp đúng màu world tương ứng với vài giá trị
  `unlockedLevel` mẫu (world 1 vs world 5 vs world 11).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Không cần `StorageKeys` mới, không cần bảng unlock riêng — 100% suy ra
  từ `GameController.unlockedLevel` (đã là `RxInt` reactive sẵn) +
  `worldForLevel`/`kWorlds` (`lib/data/worlds.dart`, đã có `GameWorld.color`
  cho cả 11 world: pink, orange, teal, ..., indigo, lime).
- Bọc phần đọc `unlockedLevel` trong `Obx` tại đúng vị trí gradient được
  build trong `home_screen.dart`, để tự động rebuild khi unlock world
  mới mà không cần thêm listener thủ công.
- Không đụng gameplay/`colorGrid`/`GameMode` nào — thuần UI ở
  `home_screen.dart`.

DoD chung: `../README.md`.
