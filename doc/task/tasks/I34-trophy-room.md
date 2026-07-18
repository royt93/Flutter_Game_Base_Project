# I34 — Trophy Room (phòng trưng bày thành tựu + mascot skin)

**Epic:** Meta/retention · **SP:** 5 · **Pri:** Should · **Deps:** không

## Mục tiêu
Thêm 1 màn hình mới "Trophy Room" gộp hiển thị: badge prestige tier (`I27`),
achievement đã unlock (`I22`), mascot skin đã sở hữu (`I30`) thành 1 nơi
"khoe" duy nhất — thay vì rải rác ở 3 màn hình khác nhau như hiện tại. Không
thêm field/state mới, chỉ tổng hợp lại dữ liệu đã có.

## Vì sao
`I22` (achievements), `I27` (prestige), `I30` (mascot wardrobe) đã implement
độc lập, mỗi cái có màn riêng — người chơi không có cảm giác "bộ sưu tập"
tổng thể. Trophy Room là lớp trình bày thuần (read-only), rẻ vì không đụng
logic gameplay/storage mới, đúng tinh thần tái dùng tối đa hạ tầng retention
đã implement.

## Acceptance criteria
- [ ] `lib/presentation/screens/trophy_room_screen.dart` (mới): 3 section
      cuộn dọc — "Prestige" (badge tier hiện tại, tái dùng widget badge đã
      tách ở `_PrestigeAction`/prestige badge widget hiện có trong
      `level_select_screen.dart`), "Thành tựu" (grid các `Achievement` đã
      unlock từ `kAchievements`/`GameController.unlockedAchievements`, mờ
      icon cho achievement chưa đạt — không lộ nội dung chưa mở), "Trang
      phục" (grid `kMascotSkins` đã sở hữu, dùng `StarMascot` với từng
      `palette` để preview, tái dùng cách render ở màn Mascot Wardrobe hiện
      có).
- [ ] Entry point: 1 nút/card mới ở `HomeScreen` (Drawer hoặc dưới hero card)
      dẫn tới `TrophyRoomScreen` — không thay thế route Achievements/Mascot
      Wardrobe hiện có (Trophy Room là tổng hợp, không phải thay thế).
- [ ] Không thêm `RxInt`/storage key mới — toàn bộ dữ liệu đọc trực tiếp từ
      `GameController` (`prestigeTier`, `unlockedAchievements`,
      `unlockedMascotSkins`) đã có sẵn.
- [ ] i18n đủ 22 locale cho tiêu đề màn hình + 3 section header.
- [ ] Widget test: `TrophyRoomScreen` render đủ 3 section; achievement/skin
      chưa unlock hiển thị trạng thái khoá (không throw khi danh sách unlock
      rỗng); có prestige tier > 0 hiện đúng badge, tier 0 ẩn badge hoặc hiện
      trạng thái "chưa prestige".
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- Đây là task thuần UI/tổng hợp — không sửa `GameController` hay bất kỳ
  logic pure nào, giảm rủi ro regression tối đa so với các task khác trong
  đợt này.
- Dialog pattern trong `CLAUDE.md`: đây là 1 screen route riêng (không phải
  dialog full-screen Flame), nên dùng `Get.to`/route bình thường như
  `AchievementsScreen`/`MascotWardrobeScreen` hiện có, không cần
  `NeonDialog.overlay`.

DoD chung: `../README.md`.
