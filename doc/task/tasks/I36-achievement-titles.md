# I36 — Achievement Titles (danh hiệu hiển thị cạnh tên người chơi)

**Epic:** Meta/retention · **SP:** 3 · **Pri:** Could · **Deps:** không

## Mục tiêu
Mỗi `Achievement` (`lib/data/achievements.dart`) đã có `titleKey` (dùng làm
tên hiển thị trong danh sách achievement) — cho phép người chơi chọn 1
achievement đã unlock làm "danh hiệu" (title) hiển thị cạnh `playerName` ở
Home Screen và trong leaderboard bạn bè (`I9`), thay vì chỉ hiện tên trần.

## Vì sao
25 achievement (`kAchievements`) hiện chỉ có giá trị nhất thời lúc unlock
(popup + coin reward) rồi biến mất khỏi tầm nhìn thường trực. Cho chọn 1 cái
làm danh hiệu thường trực biến chúng thành trang sức xã hội — tái dùng đúng
field `titleKey` đã tồn tại, không cần thêm text/asset mới.

## Acceptance criteria
- [ ] `GameController`: `RxString activeAchievementTitleId` (rỗng = không có
      danh hiệu) + `StorageKeys.activeAchievementTitleId` (mới). Method
      `setActiveTitle(String achievementId)` — chỉ nhận id có trong
      `unlockedAchievements` hiện tại (chặn set danh hiệu chưa unlock), lưu
      + cập nhật ngay. Method `clearActiveTitle()`.
- [ ] Getter tiện: `Achievement? get activeTitleAchievement` — tra
      `kAchievements.firstWhereOrNull((a) => a.id == activeAchievementTitleId.value)`
      (dùng `firstWhereOrNull` từ package `collection` đã có sẵn trong
      project, hoặc `try/firstWhere` — kiểm tra import hiện có trước khi
      thêm dependency).
- [ ] Nếu 1 achievement đang active bị mất unlock (không xảy ra trong thực tế
      vì unlock vĩnh viễn, nhưng `resetProgress()` xoá `unlockedAchievements`)
      → `resetProgress()` phải xoá luôn `activeAchievementTitleId` (tránh
      hiện danh hiệu "ma" của achievement đã bị xoá).
- [ ] UI: `HomeScreen` hiện `playerName` kèm `activeTitleAchievement.titleKey.tr`
      trong ngoặc/dưới tên (ẩn hoàn toàn nếu rỗng); màn chọn danh hiệu (thêm
      vào `AchievementsScreen` hiện có — nút "Đặt làm danh hiệu" trên mỗi
      achievement đã unlock, không tạo màn mới); `I9` leaderboard bạn bè
      hiện danh hiệu cạnh tên người chơi trong `LeaderboardEntry` hiển thị
      (không đổi cấu trúc `LeaderboardEntry` — chỉ ghép chuỗi ở nơi render UI).
- [ ] i18n đủ 22 locale cho label nút "Đặt làm danh hiệu"/"Bỏ danh hiệu".
- [ ] Test `GameController`: `setActiveTitle` với id chưa unlock → không đổi
      giá trị (giữ nguyên/rỗng); với id đã unlock → set đúng + persist; xóa
      qua `clearActiveTitle`; `resetProgress()` xoá `activeAchievementTitleId`
      về rỗng.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `titleKey`/`descKey` trên `Achievement` (`lib/data/achievements.dart`) vốn
  dùng làm tên/mô tả hiển thị trong list achievement — tái dùng nguyên `.tr`,
  không cần thêm key i18n riêng cho từng achievement.
- Không đổi `AchievementMetric`/`kAchievements` — task này chỉ thêm 1 lớp
  "đang chọn cái nào để hiện" phía trên dữ liệu đã có.

DoD chung: `../README.md`.
