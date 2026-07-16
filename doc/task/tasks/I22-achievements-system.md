# I22 — Hệ thống Achievements (thành tựu vanity, không ảnh hưởng gameplay)

**Epic:** Meta/retention · **SP:** 3 · **Pri:** Should · **Deps:** —

## Mục tiêu
Thêm 25 thành tựu cố định, mỗi cái unlock đúng 1 lần, thưởng coin 1 lần khi
đạt mốc. Hoàn toàn vanity — không đổi gameplay, không thêm currency mới,
tách biệt khỏi Relic/Perk (F14). Spec đầy đủ tại
`docs/superpowers/specs/2026-07-16-achievements-design.md`.

## Vì sao
User (đang chơi 200 level campaign tuyến tính) muốn thêm động lực dài hạn
ngoài việc lên level — thành tựu theo cột mốc tích lũy đời (tổng gem đã nổ,
combo cao nhất, số level 3 sao, số lần dọn sạch bàn, số booster đã dùng) cho
người chơi mục tiêu để quay lại ngay cả sau khi hết level mới.

## Acceptance criteria
- [x] `lib/data/achievements.dart` — `AchievementMetric` enum (5 metric),
      `Achievement` class, `kAchievements` (25 item, 5 mốc/metric tăng dần),
      `newlyUnlockedAchievementIds(...)` pure helper để tính mốc vừa vượt qua.
- [x] `GameController` — 5 `RxInt` counter mới (`totalGemsPopped`,
      `maxComboEver`, `levelsThreeStarred`, `boardsFullyCleared`,
      `totalBoostersUsed`) + `StorageKeys` tương ứng, cộng dồn đúng tại
      `registerPop`, `checkEnd`, các `use*` booster; persist ngay qua
      `StorageService.to.setInt`; xoá sạch trong `resetProgress()`.
- [x] Cơ chế unlock: `unlockedAchievementIds` (Set, CSV persist giống
      `activePerks`), `justUnlockedAchievement` (`Rxn<Achievement>`) theo
      đúng pattern Rx async có sẵn (`ended`, `justUnlocked`) — không dùng
      `Get.dialog`/`showDialog`.
- [x] `AchievementsScreen` mới — liệt kê 25 thành tựu, đánh dấu đã/chưa
      unlock, hiện tiến độ hiện tại/threshold.
- [x] Entry point: icon `emoji_events_rounded` trên `HomeScreen` (hàng icon
      riêng, không gộp vào hàng 4-icon để tránh overflow ngang trên màn hình
      hẹp) + card trong `GuideScreen` (mục cuối của `ListView.separated`, để
      tránh ListView virtualization ăn mất item cuối khi có sibling cố định
      chiếm chỗ).
- [x] Dialog ăn mừng khi unlock — `GameScreenController` lắng nghe
      `ever(gameCtrl.justUnlockedAchievement, ...)`, hiện `NeonDialog.overlay`.
- [x] i18n đủ 22 locale (English + Vietnamese trong `_extraEn`/`_extraVi`,
      20 ngôn ngữ còn lại trong wave map `_w35ByLang`).
- [x] Test: `test/data/achievements_test.dart` (data model +
      `newlyUnlockedAchievementIds`), test tích hợp trong
      `game_controller_test.dart`.
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      (238 test pass).

## Ghi chú
- Wave-map i18n hiện tại đã lên tới `_w35ByLang` (không phải `_w32` như dự
  kiến ban đầu trong spec — số thứ tự thực tế phụ thuộc các wave đã có sẵn
  trong working tree tại thời điểm implement).
- `HomeScreen`: thử gộp icon achievements vào hàng icon cuối (5 icon) từng
  gây tràn ngang (`boxed: true` = 60x60px cố định, 5×60+4×24=396px > 360px
  logical width trên viewport test điện thoại hẹp) — đã revert về hàng riêng
  và bù khoảng trống dọc bằng cách giảm gap `StarMascot`↔tên app từ `s16`
  xuống `s8`.

DoD chung: `../README.md`.
