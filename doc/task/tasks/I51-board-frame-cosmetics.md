# I51 — Board Frame Cosmetics

**Epic:** Cảm giác/A-V (cosmetic độc quyền) · **SP:** 5 · **Pri:** Could
· **Deps:** không

## Mục tiêu

Thêm 1 hệ thống "khung viền bàn chơi" (board frame) — cosmetic thuần, đổi
viền/glow bao quanh khu vực bàn trong `game_screen.dart`. Mở khoá qua
mốc `prestigeTier` (I27) và/hoặc `kAchievements` (I22) — vd tier
Prestige 1 mở khung "Neon Cyan", tier 3 mở "Aurora Gold", đạt achievement
tier cao nhất của `boardsFullyCleared` mở "Diamond Frame". Người chơi
chọn khung đang dùng qua 1 màn chọn (grid các khung đã/chưa mở khoá).

## Vì sao

Game đã có mascot skin (I30, đổi hình nhân vật) nhưng chưa có cosmetic
nào tác động trực tiếp lên khu vực bàn chơi chính — nơi người chơi nhìn
nhiều nhất mỗi ván. Board Frame tận dụng đúng các mốc độc quyền đã có sẵn
(Prestige tier, Achievement tier) làm gate mở khoá, không cần thêm hệ
thống unlock mới, chỉ cần thêm 1 lớp trang trí + 1 storage key chọn khung
đang active.

## Acceptance criteria

- [ ] Danh sách khung cố định trong `lib/data/board_frames.dart`
  (tương tự cấu trúc `Achievement`): `class BoardFrame { id, nameKey,
  unlockCondition }` — `unlockCondition` là 1 enum/kiểu đơn giản mô tả
  điều kiện (vd `PrestigeTierAtLeast(1)`, `AchievementUnlocked(id)`),
  tối thiểu 4 khung (1 mặc định luôn mở + 3 khung khoá).
- [ ] Hàm pure `bool isBoardFrameUnlocked(BoardFrame frame, int
  prestigeTier, Set<String> unlockedAchievementIds)` — kiểm tra điều
  kiện, không phụ thuộc GetX/Flutter.
- [ ] `StorageKeys.activeBoardFrame` (id khung đang chọn, mặc định khung
  đầu tiên) lưu/đọc qua `StorageService`.
- [ ] Màn chọn khung (dialog hoặc screen riêng, tái dùng
  `NeonDialog.overlay` nếu là dialog trong `GameScreen`, hoặc 1 screen
  riêng mở từ home — chọn theo mức tái dùng UI đơn giản nhất): hiển thị
  lưới khung, khung chưa mở hiện mờ + điều kiện mở khoá (text), tap khung
  đã mở để chọn active.
- [ ] `game_screen.dart` áp `BoardFrame` đang active làm decoration bao
  quanh `GameWidget` (border/glow màu theo khung, dùng
  `NeonTheme.glow(...)` pattern có sẵn).
- [ ] Đổi khung không ảnh hưởng gameplay (không tăng điểm/xu/booster) —
  cosmetic thuần.
- [ ] Unit test `test/data/board_frames_test.dart`: điều kiện mở khoá
  đúng cho từng loại (`PrestigeTierAtLeast`, `AchievementUnlocked`);
  khung mặc định luôn `isBoardFrameUnlocked == true` bất kể tier/
  achievement.
- [ ] i18n tên khung + mô tả điều kiện mở khoá, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Tái dùng chính xác pattern lưu skin đang active dạng string/id đơn giản
  đã dùng cho mascot skin (`activeMascotSkin`/`unlockedMascotSkins` —
  I30) — Board Frame chỉ cần 1 khoá active vì mở khoá được suy ra runtime
  từ `prestigeTier`/`unlockedAchievements` hiện có (không cần lưu riêng
  "danh sách đã mở" như mascot skin, vì điều kiện luôn tính lại được từ
  state đã có sẵn).
- `prestigeTier` đọc từ `GameController` (I27, đã có sẵn field theo ghi
  chú `storage_service.dart` dòng 91-94); `unlockedAchievements` đọc từ
  `StorageKeys.unlockedAchievements` (I22) — parse sang `Set<String>`
  theo đúng cách `AchievementsScreen`/`TrophyRoomScreen` hiện đọc.
- Không cần obstacle/gift/boss/pop_detector nào — cosmetic thuần ở tầng
  UI, không đụng `colorGrid`.

DoD chung: `../README.md`.
