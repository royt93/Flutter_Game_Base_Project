# I33 — Modifier Gauntlet hằng ngày

**Epic:** Gameplay depth · **SP:** 8 · **Pri:** Could · **Deps:** không

## Mục tiêu
Thêm 1 chế độ chơi mới "Gauntlet" (entry point riêng cạnh Daily
Challenge/Zen/Time-attack): mỗi ngày chọn ngẫu nhiên (seed = ngày, xem
`I28`/`F13`) 1 trong vài "modifier" cố định thay đổi luật chơi (ví dụ:
"Không undo", "Combo timer rút ngắn còn 1.5s", "Chỉ 4 màu dù world khó",
"Gravity đảo chiều" tái dùng `I3-gravity-variants`), áp lên đúng 1 bàn
`dailyChallengeRows x dailyChallengeCols` (tái dùng board size của F13), thi
điểm với leaderboard bot riêng.

## Vì sao
`I8-weekend-event` chỉ nhân hệ số coin, `F13-daily-challenge` luôn cùng luật
chơi mỗi ngày → người chơi lâu năm dễ nhàm. Modifier xoay vòng tạo biến số
mới mà không cần thiết kế thêm level nào (không tăng chi phí nội dung, đúng
tinh thần "không backend, tái dùng hạ tầng có sẵn").

## Acceptance criteria
- [ ] `lib/data/gauntlet_modifiers.dart` (mới): enum hoặc class
      `GauntletModifier` liệt kê tối thiểu 4 modifier cố định (id, nameKey,
      descKey, hàm áp dụng lên `PopStarGame` hoặc cấu hình truyền vào
      constructor — ví dụ field `bool disableUndo`, `double? comboWindowOverride`,
      `bool reverseGravity` tái dùng `I3`, `int? colorCountOverride`).
- [ ] Hàm pure `GauntletModifier modifierForDay(int epochDay)` — chọn
      modifier theo `epochDay % kGauntletModifiers.length` (đơn giản, không
      cần `Random` vì chỉ có vài lựa chọn cố định, tránh lệch giữa các thiết
      bị nếu dùng seed ngẫu nhiên không đồng bộ).
- [ ] `PopStarGame`/`GameController`: nhận modifier hiện tại, áp dụng đúng
      field tương ứng (ví dụ nếu `disableUndo == true` thì `useUndo()` luôn
      trả false bất kể `undoCount`).
- [ ] `lib/data/daily_challenge_leaderboard_bots.dart`-style: thêm
      `kGauntletLeaderboardBots` (const list điểm mẫu riêng, không dùng
      chung thang điểm Daily Challenge vì luật chơi khác).
- [ ] `GameController`: `StorageKeys.lastGauntletDay`/`gauntletScore` riêng
      (theo đúng pattern `lastDailyChallengeDay`/`dailyChallengeScore` đã có),
      1 lần chơi/ngày.
- [ ] UI: entry point mới ở Home/mode select hiện modifier hôm nay (icon +
      tên) trước khi vào chơi; màn kết quả hiện leaderboard giống Daily
      Challenge (tái dùng `buildLeaderboard`/`playerRank` từ
      `lib/logic/leaderboard.dart`).
- [ ] i18n đủ 22 locale cho tên/mô tả từng modifier + label mode.
- [ ] Test pure: `modifierForDay` — chọn đúng modifier theo epoch day, tuần
      hoàn đúng chu kỳ `kGauntletModifiers.length`. Test từng modifier áp
      dụng đúng field (disableUndo chặn undo, colorCountOverride đổi đúng số
      màu sinh board).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `F13-daily-challenge.md`/`dailyChallengeRows`/`dailyChallengeCols` đã định
  nghĩa kích thước bàn cố định cho chế độ 1-lần/ngày — tái dùng y hệt, không
  tạo kích thước bàn mới.
- `I3-gravity-variants` đã có field đảo chiều gravity trong
  `applyGravityAndCollapse`/`PopStarGame` — chỉ cần truyền cờ có sẵn, không
  viết lại logic gravity.
- Tránh nhầm với `I8-weekend-event` (chỉ nhân coin, không đổi luật) — Gauntlet
  là mode riêng biệt, không áp modifier lên campaign thường.

DoD chung: `../README.md`.
