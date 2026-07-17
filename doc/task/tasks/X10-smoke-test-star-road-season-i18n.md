# X10 — Smoke test tổng + fix i18n hardcode (Star Road, Season Pass)

**Epic:** i18n/polish · **SP:** 2 · **Pri:** Should · **Deps:** X7, I22, I23

## Mục tiêu
Playtest tay toàn bộ app trên thiết bị thật (Pixel 7 Pro) sau loạt task
#13-#19 (World 11, boss variant, booster thứ 4, weekend event, friend
compare, achievements, perfect clear, test coverage) để bắt regression mà
test tự động không thấy được (UI/UX thật, locale hiển thị, dialog overlay).

Qua playtest phát hiện thêm 2 màn hardcode chuỗi tiếng Anh y hệt kiểu lỗi
X7 đã fix trước đó, nhưng KHÔNG nằm trong phạm vi X7:
- `lib/presentation/screens/star_road_screen.dart` — title `'Star Road'`,
  `'$milestone stars'`, `'Claimed'`, `'... reward ... coins'`, `'CLAIM'`.
- `lib/presentation/screens/season_screen.dart` — title `'Season Pass'`,
  `'$milestone points'`, `'Claimed'`, `'... reward ...'`, `'CLAIM'`.

## Vì sao
Cùng lý do X7: mọi text hiển thị phải qua `AppTranslations`/`.tr` để giữ
parity 22 locale. Cả 2 màn trên chưa từng được đưa vào diện rà soát trước
đó — bị bỏ sót vì không nằm trong nhóm home/leaderboard mà X7 đã quét.

## Phạm vi playtest (đã tick tay trên device thật, không có ad nào xuất hiện)
- Home (drawer + banner ưu tiên + 3 icon quick-access), Modes dialog, Shop,
  Daily Challenge.
- Drawer: Star Road, Spin Wheel, Guide, Settings, Leaderboard, Friend
  Compare, Season Pass, Perks, Achievements.
- Level Select + gameplay (pop/gravity/collapse), tutorial tooltip, quit
  dialog (overlay pattern).

## Acceptance criteria
- [x] `star_road_screen.dart`: title dùng `'star_road_title'.tr` (key có
      sẵn), số mốc hiện dạng icon sao + số (không còn chữ "stars"), dòng
      progress hiện `$totalStars/$milestone` (số thuần, giống
      `achievements_screen.dart`), "Claimed" → `'ach_claimed'.tr`, "CLAIM"
      → `'daily_claim'.tr.toUpperCase()`.
- [x] `season_screen.dart`: title dùng `'season_pass_title'.tr` (key có
      sẵn), dòng mốc dùng `'season_points'.tr` (key có sẵn), progress hiện
      số thuần, reward hiện dạng icon (coin/bomb/shuffle/undo) + số thay
      chữ "coins"/"bomb"/..., "Claimed"/"CLAIM" dùng lại key như trên.
- [x] Không thêm key dịch mới nào — toàn bộ tái dùng key đã có sẵn ở 22
      locale (`star_road_title`, `season_pass_title`, `season_points`,
      `ach_claimed`, `daily_claim`).
- [x] `test/widget/star_road_screen_test.dart` cập nhật theo text mới
      (`'DAILY_CLAIM'` — key thô vì test không setup `AppTranslations`,
      giống pattern `achievements_screen_test.dart` đã dùng).
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      (261 test).
- [x] Build lại APK, cài lên thiết bị thật, xác nhận cả 2 màn hiện đúng
      tiếng Việt qua screenshot.

## Ghi chú kỹ thuật
Spin Wheel dialog (`spin_wheel_dialog.dart`) hiện hardcode tiếng Việt
thẳng (không qua `.tr` luôn, không riêng tiếng Anh) — không phải lỗi mới
phát hiện lần này (không hiện sai trong locale VI đang test), để lại cho
lần rà soát i18n tiếp theo, không mở rộng phạm vi task này.

## Đã code (2026-07-17)
Fix 2 file, mỗi file 1 commit riêng sau khi test xanh. Không thêm wave i18n
mới — chỉ tái cấu trúc UI để tái dùng key đã dịch sẵn (đúng tinh thần
"reuse trước khi invent").

DoD chung: `../README.md`.
