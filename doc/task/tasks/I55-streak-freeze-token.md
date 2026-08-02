# I55 — Streak Freeze Token

**Epic:** Meta/retention · **SP:** 3 · **Pri:** Should
· **Deps:** I48 (Login Streak Calendar)

## Mục tiêu

Thêm vật phẩm "Streak Freeze" bảo vệ login streak (I48) khi người chơi lỡ
đúng 1 ngày — thay vì reset về 1, giữ nguyên streak nếu có ít nhất 1 token
tại thời điểm phát hiện gap. Token đổi bằng coin qua cửa hàng, theo đúng
pattern các booster hiện có.

## Vì sao

`nextLoginStreak()` hiện reset cứng streak về 1 khi lỡ ≥1 ngày, không có
cơ chế "tha lỗi" kiểu Duolingo — đây là nguyên nhân phổ biến gây
streak-anxiety-churn ở game có streak. Reuse gần như toàn bộ hạ tầng
booster-count đã có, không cần hệ thống mới.

## Acceptance criteria

- [ ] Thêm `StorageKeys.streakFreezeCount` (int, mặc định 0) theo đúng
  pattern `swapCount`/`freezeCount` (`lib/core/storage_service.dart` dòng
  27-33).
- [ ] Thêm hàm mới trong `lib/logic/login_streak.dart` (không sửa
  `nextLoginStreak()` gốc — giữ tương thích ngược cho test cũ), vd
  `({int streak, bool usedFreeze}) nextLoginStreakWithFreeze({required
  int previousEpochDay, required int todayEpochDay, required int
  previousStreak, required bool hasFreezeAvailable})`: khi `gap == 2` và
  `hasFreezeAvailable == true` → giữ nguyên `previousStreak`, báo
  `usedFreeze = true`; các trường hợp khác gọi lại `nextLoginStreak()` y
  hệt logic cũ.
- [ ] `GameController._updateLoginStreak()`
  (`lib/presentation/controllers/game_controller.dart` dòng ~850-875) gọi
  hàm mới, trừ 1 `streakFreezeCount` khi `usedFreeze == true`, ghi lại
  storage.
- [ ] Thêm `buyStreakFreeze()` theo đúng pattern `buyFreeze()`/`_buy()`
  helper (dòng ~1549-1550) — mua bằng coin, giá cố định.
- [ ] `login_streak_dialog.dart` (dòng 10-49) hiển thị số token đang có +
  nút mua khi hụt streak, cạnh lịch 7 ngày hiện có.
- [ ] Freeze chỉ bảo vệ login streak — không đụng `weeklyGoalProgress`
  (I50), tránh chồng lấn 2 hệ thống độc lập nhau.
- [ ] Unit test mở rộng `test/logic/login_streak_test.dart`: gap==2 +
  có freeze → giữ streak, `usedFreeze=true`; gap==2 + không freeze →
  reset về 1 (behavior cũ không đổi); gap==1 → +1, không đụng freeze
  (`usedFreeze=false`).
- [ ] i18n tên vật phẩm + mô tả mua, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Tái dùng chính xác pattern lưu số lượng booster dạng `int` count
  (`freezeCount` v.v.) — không cần bảng dữ liệu riêng vì chỉ có 1 loại
  token.
- `_buy()` helper đã generic hoá mua/tăng count qua `StorageKeys` — chỉ
  cần thêm 1 lệnh gọi tương tự `buyFreeze()`.
- Thuần meta/retention, không đụng `colorGrid`/gameplay pop.

DoD chung: `../README.md`.
