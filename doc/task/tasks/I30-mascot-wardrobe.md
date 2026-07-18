# I30 — Mascot Wardrobe (skin cho StarMascot)

**Epic:** Cảm giác/A-V · **SP:** 5 · **Pri:** Could · **Deps:** không (dùng
xu sẵn có, không phụ thuộc I27 Prestige)

## Mục tiêu
Thêm skin/trang phục cho `StarMascot` — unlock qua đạt achievement (25 mốc
đã có ở I22) và/hoặc mua trực tiếp bằng xu sẵn có. Người chơi chọn 1 skin
đang active; mascot hiển thị đúng skin ở mọi nơi nó xuất hiện.

## Vì sao
`StarMascot` hiện vẽ thuần bằng `CustomPainter` (không asset ảnh) — đổi
màu/hoạ tiết là mở rộng tự nhiên, rẻ. Tái dùng đúng 2 hệ thống đã có
(achievement để unlock miễn phí, xu để mua) thay vì tạo currency/progression
mới, đúng quyết định user: dùng xu sẵn có, không phụ thuộc Prestige (I27).

## Acceptance criteria
- [ ] `lib/data/mascot_skins.dart` (mới): `MascotSkin` (id, tên key i18n,
      palette màu override, giá xu **hoặc** `unlockAchievementId` — mỗi
      skin chỉ 1 trong 2 cách mở khoá), `kMascotSkins` danh sách cố định
      (gồm 1 skin mặc định miễn phí + vài skin mua bằng xu + vài skin gắn
      achievement mốc cao).
- [ ] `_StarPainter` (`star_mascot.dart`) nhận tham số palette màu thay vì
      hardcode — chỉ đổi màu/hoạ tiết theo skin, giữ nguyên hình dạng ngôi
      sao và toàn bộ animation mood hiện có.
- [ ] `GameController`: `RxString activeMascotSkinId`, `RxSet<String>
      unlockedMascotSkinIds` + `StorageKeys` tương ứng. `buySkin(MascotSkin)`
      tái dùng đúng pattern `_buy()` (kiểm tra đủ xu → trừ xu → thêm vào
      unlocked set → lưu storage). Hook vào `_checkAchievements()`: khi đạt
      mốc gắn với 1 skin, tự thêm skin đó vào `unlockedMascotSkinIds` (không
      cần mua).
- [ ] Màn hình chọn skin mới (`MascotWardrobeScreen`) — lưới skin theo
      pattern UI shop hiện có (`_BoosterRow`-style): preview mascot, trạng
      thái khoá/mở, giá hoặc điều kiện achievement, nút chọn/mua.
- [ ] Entry point trên `HomeScreen` (icon riêng hoặc tap trực tiếp vào
      `StarMascot`).
- [ ] `resetProgress()` reset `activeMascotSkinId`/`unlockedMascotSkinIds`
      về mặc định (chỉ còn skin free).
- [ ] i18n đủ 22 locale (tên skin, điều kiện mở khoá, nút chọn/mua).
- [ ] Test: logic unlock qua achievement + mua bằng xu trong
      `game_controller_test.dart` (đủ xu → trừ đúng, không đủ xu → không
      trừ/không unlock, mua trùng skin đã unlock → không trừ xu lần 2).
      Widget test: mascot vẽ đúng palette khi đổi skin active.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `StarMascot`/`_StarPainter`: `lib/presentation/widgets/star_mascot.dart`
  (mood idle/happy/sad/cheer; painter vẽ thuần canvas, không asset ảnh).
- Pattern mua bằng xu: `GameController._buy(int price, RxInt count, String
  key)` trong `lib/presentation/controllers/game_controller.dart` — Wardrobe
  cần biến thể tương tự nhưng track theo `Set<String>` id thay vì đếm số
  lượng.
- Achievement system: `lib/data/achievements.dart` (`AchievementMetric`,
  `kAchievements` 25 mốc), hook unlock tại
  `GameController._checkAchievements()`.
- UI pattern tham khảo: `lib/presentation/screens/shop_screen.dart`
  (`_BoosterRow`).

DoD chung: `../README.md`.
