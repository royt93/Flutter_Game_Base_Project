# I38 — Weekly Featured Level

**Epic:** Social/competitive · **SP:** 3 · **Pri:** Could · **Deps:** không

## Mục tiêu
Mỗi tuần (seed theo số tuần epoch), chọn ngẫu nhiên 1 trong 220 level campaign
đã unlock làm "Level tuần này" — chơi lại level đó (không tính vào tiến độ
unlock, không giới hạn số lần chơi) để cạnh tranh điểm cao nhất trên
leaderboard bot riêng, tương tự `F13`/`I9` nhưng dùng lại đúng nội dung
campaign thay vì bàn riêng.

## Vì sao
`F13-daily-challenge` dùng board riêng biệt (`dailyChallengeRows/Cols`, khác
hẳn 220 level đã cân bằng kỹ theo `CLAUDE.md`). Weekly Featured Level là biến
thể rẻ hơn nhiều: không cần thiết kế board mới, chỉ chọn 1 level đã có sẵn
target/độ khó cân bằng, tạo lý do quay lại chơi lại level cũ mỗi tuần theo
nhịp khác Daily Challenge (tuần vs ngày).

## Acceptance criteria
- [ ] Hàm pure trong `lib/data/levels.dart` (hoặc file mới
      `lib/data/weekly_featured.dart`): `int featuredLevelIdForWeek(int epochWeek)`
      — `epochWeek % kLevelCount + 1` (chỉ chọn trong phạm vi level ĐÃ unlock
      của người chơi tại thời điểm hiển thị, xem note bên dưới), deterministic
      theo tuần, không cần `Random`.
- [ ] `GameController`: `StorageKeys.lastFeaturedWeekSeen`/`featuredLevelScore`
      (best score riêng cho lượt chơi featured, không ghi đè
      `StorageKeys.highScore(levelId)` của campaign thường — 2 thang điểm
      tách biệt vì mục đích khác nhau, dù cùng level).
- [ ] Nếu `featuredLevelIdForWeek(currentWeek) > unlockedLevel.value`: hiện
      thông báo "Level tuần này chưa mở khoá" thay vì cho chơi (không được
      bỏ qua tiến trình unlock tuần tự của campaign) — chọn lại level tuần
      hợp lệ gần nhất đã unlock (ví dụ modulo theo `unlockedLevel.value`
      thay vì `kLevelCount` cố định, để luôn có level chơi được).
- [ ] Leaderboard bot riêng `kWeeklyFeaturedLeaderboardBots`
      (const list điểm mẫu, theo đúng pattern
      `kDailyChallengeLeaderboardBots`/`lib/data/daily_challenge_leaderboard_bots.dart`).
- [ ] UI: entry point mới ở Home hiện tên/world level tuần này + best score
      hiện tại; màn kết quả hiện leaderboard (tái dùng
      `buildLeaderboard`/`playerRank`, `lib/logic/leaderboard.dart`).
- [ ] i18n đủ 22 locale.
- [ ] Test pure: `featuredLevelIdForWeek` — cùng tuần luôn ra cùng level, đổi
      tuần ra level khác (xác suất cao trên vài tuần mẫu), giá trị luôn trong
      `1..kLevelCount`.
- [ ] Test `GameController`: level tuần chưa unlock → chặn chơi + chọn level
      thay thế đã unlock; chơi xong cập nhật đúng `featuredLevelScore` (chỉ
      tăng, không giảm nếu điểm mới thấp hơn best cũ — giống cách
      `highScore` hoạt động).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `kLevelCount = 220` (`lib/data/levels.dart`) — chú ý con số thật này (không
  phải 200 như `CLAUDE.md` ghi, đã lệch từ khi thêm world 11, xem ghi chú
  tương tự ở `I27`).
- Tính "epoch week": dùng cùng cơ sở epoch day đã có
  (`StorageKeys.maxEpochDaySeen`/pattern tính ngày ở `comeback_bonus.dart`)
  chia 7 — không cần thêm helper thời gian mới nếu 1 hàm epoch-day chung đã
  tồn tại, chỉ cần `epochDay ~/ 7`.
- Không đụng `unlockedLevel`/`highScore(levelId)` của campaign thật — mọi
  progress/điểm của Weekly Featured phải nằm hoàn toàn tách biệt để không
  làm sai lệch tiến trình 3-sao chính của level đó.

DoD chung: `../README.md`.
