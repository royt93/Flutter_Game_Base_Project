# I52 — Pop Burst Style Picker

**Epic:** Cảm giác/A-V (cosmetic độc quyền) · **SP:** 5 · **Pri:** Could
· **Deps:** không

## Mục tiêu

Cho phép người chơi chọn 1 trong nhiều "kiểu hiệu ứng nổ" (burst style)
khi pop 1 nhóm gem — thay thế phần particle hiện tại (`_spawnBurst`,
dùng `ParticleSystemComponent`/`ComputedParticle`) bằng 1 trong các biến
thể đã mở khoá: mặc định "Spark" (hiện tại), cộng thêm "Confetti"
(hạt vuông nhiều màu), "Ripple" (vòng tròn lan toả thay vì hạt văng),
"Starburst" (hạt hình sao). Mở khoá qua các mốc `AchievementMetric.
totalGemsPopped` (I22) — mỗi tier đạt được mở 1 style mới.

## Vì sao

`_spawnBurst` là hiệu ứng người chơi nhìn thấy **nhiều nhất** trong toàn
bộ game (mỗi lần pop), nên là cosmetic có độ "cảm nhận được" cao nhất mà
chi phí thấp nhất (chỉ đổi tham số particle, không đổi luật chơi). Gắn
mở khoá vào chính `totalGemsPopped` (thước đo cày cuốc tự nhiên nhất,
tăng đều đặn) tạo động lực "chơi nhiều hơn để đổi hiệu ứng", khác hẳn
hướng unlock theo Prestige/Achievement-tier-cụ-thể của I51.

## Acceptance criteria

- [ ] `lib/game/pop_star_game.dart`: tách phần tạo `ParticleSystemComponent`
  hiện tại trong `_spawnBurst` thành 1 hàm nhận thêm tham số
  `BurstStyleKind kind` (enum `spark, confetti, ripple, starburst`) —
  mỗi kind dùng 1 cấu hình `ComputedParticle` khác (số hạt, hình dạng,
  tốc độ/hướng văng, thời gian sống) nhưng **cùng 1 điểm gọi**
  `_spawnBurst(cells, kind)` như hiện tại (không đổi signature gọi từ
  nơi khác trong file).
- [ ] `lib/data/burst_styles.dart` (mới): danh sách 4 style cố định với
  ngưỡng mở khoá (`totalGemsPopped` threshold, vd 0/500/2000/5000 — tái
  dùng đúng tier threshold pattern của `kAchievements`).
- [ ] `StorageKeys.activeBurstStyle` lưu id style đang chọn (mặc định
  `spark`, luôn mở khoá).
- [ ] Màn/dialog chọn style: hiển thị 4 lựa chọn, style chưa đủ
  `totalGemsPopped` hiện mờ + ngưỡng cần đạt, tap style đã mở để chọn.
- [ ] `PopStarGame` đọc `StorageKeys.activeBurstStyle` khi khởi tạo (qua
  `GameController` hoặc trực tiếp `StorageService.to`) để quyết định
  `kind` truyền vào `_spawnBurst` mỗi lần pop.
- [ ] Đổi style không ảnh hưởng gameplay (không tăng điểm/xu) — cosmetic
  thuần, không đổi thời gian animation tổng thể đủ để không phá nhịp
  `_animating` lock hiện có.
- [ ] Unit test `test/data/burst_styles_test.dart`: hàm
  `bool isBurstStyleUnlocked(BurstStyle style, int totalGemsPopped)` —
  đúng ngưỡng, style mặc định luôn mở khoá.
- [ ] i18n tên style, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ. Test animation cần đảm bảo không tăng runtime golden test/widget
  test hiện có do đổi tham số particle.

## Ghi chú kỹ thuật

- Không tạo `class` mới cho particle — chỉ tham số hoá hàm dựng
  `ComputedParticle` hiện có trong `_spawnBurst` theo `BurstStyleKind`,
  giữ nguyên cấu trúc animation/`_animating` lock đã có, tránh đổi luồng
  điều khiển.
- `totalGemsPopped` đã là 1 `AchievementMetric` có sẵn
  (`lib/data/achievements.dart`) — đọc trực tiếp giá trị hiện tại từ
  `StorageKeys.totalGemsPopped` (đã tồn tại), không cần thêm biến đếm
  mới.
- Không đụng `colorGrid`/`pop_detector`/`obstacle` — cosmetic thuần ở
  tầng render.

DoD chung: `../README.md`.
