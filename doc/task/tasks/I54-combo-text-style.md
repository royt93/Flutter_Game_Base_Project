# I54 — Combo Text Style

**Epic:** Cảm giác/A-V (cosmetic độc quyền) · **SP:** 3 · **Pri:** Could
· **Deps:** không

## Mục tiêu

Cho phép người chơi chọn 1 trong nhiều "kiểu chữ" cho text combo-milestone
hiện ra khi đạt mốc combo (5/10/15/20 — `kComboMilestones`) — vd mặc định
"Neon" (kiểu hiện tại), thêm "Bold Pop" (chữ to, nảy mạnh hơn), "Retro"
(font/màu khác), "Fire" (hiệu ứng màu lửa gradient theo text). Mở khoá
qua `AchievementMetric.maxComboEver` (I22) — mỗi tier đạt được (vd đạt
combo 10 lần đầu tiên) mở 1 style.

## Vì sao

Text combo-milestone là điểm nhấn cảm xúc rõ rệt nhất khi người chơi chơi
tốt (ăn combo lớn) — cosmetic rẻ, tận dụng đúng hạ tầng
`hapticForComboMilestone`/`triggerComboMilestone` đã có sẵn (chỉ đổi
phần hiển thị text, không đổi ngưỡng/logic combo). Bổ sung bộ 3 cosmetic
(I51 khung bàn, I52 hiệu ứng nổ, I54 chữ combo) phủ 3 điểm nhìn khác nhau
trong 1 ván chơi: viền bàn (luôn thấy), hiệu ứng nổ (mỗi lần pop), chữ
combo (lúc chơi tốt) — không cosmetic nào chồng lấn phạm vi cosmetic
khác.

## Acceptance criteria

- [ ] `lib/data/combo_text_styles.dart` (mới): 4 style cố định
  (`neon, boldPop, retro, fire`) với ngưỡng mở khoá theo
  `maxComboEver` (tái dùng đúng tier threshold của `kAchievements` cho
  metric này, vd 0/10/15/20).
- [ ] Nơi hiện tại render text combo-milestone (nơi gọi
  `hapticForComboMilestone`/hiển thị text trong `pop_star_game.dart`
  hoặc widget overlay liên quan) nhận thêm tham số style — mỗi style đổi
  `TextStyle` (font weight/size/màu/shadow) và/hoặc animation nảy
  (scale curve), **không đổi** thời điểm/ngưỡng combo kích hoạt
  (`kComboMilestones` giữ nguyên).
- [ ] `StorageKeys.activeComboTextStyle` lưu style đang chọn (mặc định
  `neon`, luôn mở khoá).
- [ ] Màn/dialog chọn style: hiển thị preview tĩnh 4 style, style chưa
  đủ `maxComboEver` hiện mờ + ngưỡng cần đạt.
- [ ] Đổi style không ảnh hưởng ngưỡng combo/haptic/điểm số — cosmetic
  thuần trên phần hiển thị text.
- [ ] Unit test `test/data/combo_text_styles_test.dart`: hàm
  `bool isComboTextStyleUnlocked(ComboTextStyle style, int maxComboEver)`
  — đúng ngưỡng, style mặc định luôn mở khoá.
- [ ] i18n tên style, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- `maxComboEver` đã là 1 `AchievementMetric` có sẵn — đọc trực tiếp từ
  `StorageKeys.maxComboEver` (đã tồn tại), không thêm biến đếm mới.
- Không đổi `kComboMilestones`/`isComboMilestone`/
  `hapticForComboMilestone` (`lib/data/combo_milestones.dart`) — style
  chỉ tham số hoá phần render text, tách biệt hoàn toàn khỏi logic tính
  ngưỡng/haptic đã có, tránh rủi ro phá vỡ hành vi combo hiện tại.
- Không đụng `colorGrid`/gameplay — cosmetic thuần ở tầng render text.

DoD chung: `../README.md`.
