# Perfect Clear replay mode — design spec

**Ngày:** 2026-07-16 · **Task ID dự kiến:** kế tiếp sau I22 · **Epic:** Meta/retention

## Mục tiêu
Cho phép chơi lại 1 level campaign đã qua (≥1 sao) với mục tiêu khắt khe hơn:
vượt qua best score hiện tại của chính level đó. Thắng → thưởng thêm coin
bonus 1 lần cho lượt chơi đó (không phải unlock vĩnh viễn như Achievements).
Mục đích: tăng động lực chơi lại các level cũ (đặc biệt sau khi đã hết level
mới hoặc đang chờ mở khoá) mà không cần thêm nội dung level mới.

## Vì sao chọn tiêu chí "vượt best score" (không phải "ít nước đi hơn")
Cân nhắc 2 phương án:
1. **Vượt best score hiện tại** (đã chọn) — tái dùng thẳng
   `StorageKeys.highScore(id)` đã có sẵn, không cần field lưu trữ mới
   (`movesUsed` chỉ là counter tạm trong ván, không persist theo level nên
   "ít nước đi hơn lần trước" sẽ cần thêm 1 StorageKey mới per-level).
2. **Đạt 3 sao trong ít nước đi hơn lần chơi trước** — chính xác hơn về mặt
   "Perfect Clear" nhưng cần persist `movesUsed` tốt nhất mỗi level (field
   mới, migration, thêm nhánh so sánh) chỉ để phục vụ 1 chế độ phụ.

Chọn phương án 1 vì đáp ứng đúng nhu cầu (thử thách khắt khe hơn, thưởng thêm)
với diện thay đổi nhỏ nhất — không thêm StorageKey, không đổi luồng
`registerPop`/`movesUsed` hiện có.

## Phạm vi
- **Không** thêm `GameMode` mới — Perfect Clear tái sử dụng hoàn toàn
  `GameMode.campaign` (cùng `checkEnd` branch, cùng star/highscore/unlock
  logic) để tránh nhân bản nhánh campaign-vs-side-mode đã có trong
  `GameController`. Chỉ khác: có thêm 1 "target cần vượt" chụp sẵn trước khi
  chơi, và 1 cờ thành công để UI hiện badge + cộng thêm coin bonus.
- Entry point: **long-press** trên tile level đã unlock **và đã có ≥1 sao**
  trong `LevelSelectScreen` (tap ngắn vẫn giữ hành vi chơi bình thường như
  cũ — không phá test/hành vi hiện có).
- Thưởng: `perfectClearBonusCoins = 50` (hằng số, nhân `weekendCoinMultiplier`
  như mọi khoản thưởng coin khác trong game), cộng **thêm** vào coin thưởng
  sao bình thường của lượt chơi đó — không thay thế.
- Star/highscore/unlock của lượt Perfect Clear vẫn cập nhật bình thường qua
  luồng campaign hiện có (không có nhánh đặc biệt nào bị tắt).

## 1. `GameController` — field mới
```dart
/// điểm cần vượt khi đang trong 1 lần Perfect Clear challenge (chụp trước
/// khi chơi, vì _saveBestScore sẽ ghi đè highScore ngay khi thắng) — null
/// khi không phải Perfect Clear.
final perfectClearTarget = Rxn<int>();

/// set 1 lần khi vừa hoàn thành 1 lần Perfect Clear thành công, UI (dialog
/// thắng) đọc rồi tự hiện badge.
final perfectClearSuccess = false.obs;

static const int perfectClearBonusCoins = 50;
```
Lý do phải **chụp target trước khi gọi `startLevel`**: `_saveBestScore()`
(chạy cuối `checkEnd` nếu `starsEarned > 0`) ghi đè `StorageKeys.highScore(id)`
ngay khi ván hiện tại có điểm cao hơn — nếu đọc `highScore` sau khi ván đã kết
thúc thì đã là điểm của chính lượt đang xét, không còn là "best score trước
khi thử thách" nữa.

## 2. Entry point mới
```dart
/// replay level đã qua ít nhất 1 sao, mục tiêu vượt best score hiện tại —
/// thành công thưởng thêm perfectClearBonusCoins, ngoài ra dùng nguyên
/// luồng campaign (star/highscore vẫn cập nhật bình thường).
void startPerfectClear(int levelId) {
  final target = StorageService.to.getInt(StorageKeys.highScore(levelId));
  startLevel(levelId);
  perfectClearTarget.value = target;
}
```
`startLevel()` được sửa để luôn reset `perfectClearTarget = null` và
`perfectClearSuccess = false` — đảm bảo 1 lượt chơi thường (tap ngắn) sau đó
không vô tình còn dính trạng thái Perfect Clear của lượt trước.

## 3. `checkEnd` — kiểm tra thành công
Chèn ngay sau `starsEarned.value = _computeStars(); ended.value = true;` và
trước nhánh thưởng sao thường (`if (starsEarned.value > 0) { ... }`):
```dart
if (perfectClearTarget.value != null &&
    score.value > perfectClearTarget.value!) {
  perfectClearSuccess.value = true;
  coins.value += perfectClearBonusCoins * weekendCoinMultiplier;
  StorageService.to.setInt(StorageKeys.coins, coins.value);
}
```
Guard `if (ended.value) return;` ở đầu `checkEnd` (đã có sẵn) chống double-
award nếu `checkEnd` vô tình được gọi 2 lần cho cùng 1 ván.

## 4. UI — `LevelSelectScreen`
- `_LevelTile` thêm `onLongPress` (optional, không phá `onTap` hiện có).
- `_buildTile`: chỉ gắn `onLongPress` khi `!locked && stars > 0`.
- Dialog xác nhận dùng `NeonDialog.show()` (API dành cho Material route,
  không phải `NeonDialog.overlay` — vì `LevelSelectScreen` không phải màn
  Flame full-screen), 2 action `cancel`/`perfect_clear_start` theo đúng
  pattern dialog xác nhận 2 nút đã có (`settings_screen.dart` — reset
  progress).

## 5. UI — `game_screen.dart` (win dialog)
Thêm 1 dòng badge `'perfect_clear_success_label'` (icon 🏆 + số coin bonus),
hiện có điều kiện khi `gameCtrl.perfectClearSuccess.value == true`, dùng
chung `AnimatedOpacity`/timing với score hiện có trong `_WinChoreographyState`
(không thêm choreography riêng).

## 6. i18n
4 key mới: `perfect_clear_title`, `perfect_clear_msg` (`{score}`/`{coin}`
placeholder), `perfect_clear_start`, `perfect_clear_success_label`
(`{coin}` placeholder) — theo đúng convention `_extraEn`/`_extraVi` +
wave map mới (`_w36ByLang`) cho 20 ngôn ngữ còn lại.

## 7. Test
- `test/presentation/game_controller_test.dart`, group mới "Task #5 —
  Perfect Clear replay": `startPerfectClear` chụp đúng target hiện tại;
  vượt target → `perfectClearSuccess = true` + cộng đúng bonus coin (cùng
  `weekendCoinMultiplier`); không vượt target → không thành công, không
  thưởng; `startLevel` thường reset target/success về mặc định.

## Ngoài phạm vi (không làm)
- Không thêm leaderboard/ranking riêng cho Perfect Clear.
- Không thêm giới hạn số lần thử/ngày.
- Không đổi tiêu chí sang "ít nước đi hơn" (xem phần "Vì sao" ở trên).
- Không thêm `GameMode` mới hoặc StorageKey mới.
