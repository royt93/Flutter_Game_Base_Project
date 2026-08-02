# I64 — Star Constellation & Sky Shrine

**Epic:** Neon/Glow độc quyền (meta) · **SP:** 5 · **Pri:** Could
· **Deps:** không (dùng `totalStars` đã có sẵn)

## Mục tiêu

1 chuỗi "chòm sao" cố định, mỗi chòm sao "thắp sáng" khi tổng sao
(`totalStars`) đạt ngưỡng — thắp đủ chòm sao mở khoá hiệu ứng glow/aura
độc quyền áp cho theme game, cùng 1 currency thu thập "Star Seed" mang
tính sưu tầm.

## Vì sao

Game đã có `totalStars` tích luỹ nhưng chưa có đích đến ý nghĩa ngoài số
hiển thị — Sky Shrine biến cột mốc sao thành trải nghiệm thị giác
(neon/aura) đúng bản sắc "Neon/Glow độc quyền" của game, tận dụng hạ tầng
shader (`NeonAuraLayer`, `AuroraBgLayer`) đã có sẵn.

## Acceptance criteria

- [ ] `lib/data/constellations.dart` mới — danh sách `Constellation` cố
  định, mỗi phần tử có `starsRequired: int` và id hiệu ứng mở khoá liên
  kết.
- [ ] Hàm pure `isConstellationLit(Constellation c, int totalStars)`.
- [ ] `StorageKeys.starSeedCount` — currency mới, trao 1 lần duy nhất khi
  1 chòm sao thắp sáng lần đầu (idempotent — không trao lại nếu
  `totalStars` giảm rồi tăng lại qua cùng ngưỡng, vd sau prestige reset).
- [ ] Mở rộng `NeonAuraLayer` (`lib/presentation/widgets/neon_aura_layer.dart`
  dòng 11) và/hoặc `AuroraBgLayer` (dòng 12) thêm param `variant` optional
  (mặc định giữ nguyên hành vi hiện tại khi không truyền) — **ưu tiên tái
  dùng shader `.frag` hiện có với tham số màu/tốc độ khác nhau thay vì
  viết shader asset mới**, chỉ thêm shader mới nếu biến tấu tham số không
  đủ đáp ứng (giữ SP=5 hợp lý).
- [ ] Màn hình mới `sky_shrine_screen.dart` hiển thị chuỗi chòm sao,
  trạng thái thắp sáng, Star Seed đã thu.
- [ ] Ghi rõ trong PR: vị trí áp dụng hiệu ứng aura đã mở khoá (home
  screen hay game screen) là quyết định triển khai, không bắt buộc trong
  acceptance criteria.
- [ ] Ghi rõ: đích "tiêu" Star Seed nằm ngoài phạm vi task này — có thể
  tạm là số sưu tầm/thành tích thuần tuý tới khi có task khác bổ sung nơi
  tiêu.
- [ ] Unit test mới `test/data/constellations_test.dart` cho
  `isConstellationLit()` và tính idempotent của việc trao Star Seed.
- [ ] i18n toàn bộ text màn Sky Shrine, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- `totalStars` đã có sẵn (`game_controller.dart` dòng 482, cập nhật qua
  `_recomputeTotalStars()` dòng 818-824) — task này chỉ đọc, không sửa
  cách tính.
- `NeonAuraLayer`/`AuroraBgLayer` hiện chỉ nhận 1 param màu duy nhất,
  không có kiến trúc biến thể — việc thêm `variant` là thay đổi nhỏ, có
  thể chỉ cần đổi màu/tốc độ truyền vào shader hiện có.

DoD chung: `../README.md`.
