---
id: w22-4-debt-daily-i18n
title: Đóng nợ — Daily Leaderboard score + i18n tên thế giới
wave: 22
phase: 4
status: done
owner: claude
---

> ✅ **Done 2026-06-26.**
> - **4A** implement: `StorageKeys.dailyBestScore` (`'<day>|<score>'`), ghi ở
>   `game_controller_scoring.dart` nhánh daily-win, đọc trong `LeaderboardController.dailyBoard()`
>   (`dailyPlayerScore()`), screen ẩn note khi đã có điểm, thêm vào `resetProgress()`. +2 test.
> - **4B** hoá ra ĐÃ XONG sẵn: `worldNameKey()` (`levels.dart:1139`) + `world_map_screen.dart:362`
>   + `level_select_screen.dart:391` đều đã `.tr`; `world_name_1..10` dịch đủ 22 ngôn ngữ.
>   (Báo cáo "chưa wire" trước đó là sai — đã xác minh code.)
> - analyze 0, full suite 750 pass.
---

# Phase 4 — Đóng nợ (2 việc nhỏ, thắng dễ)

## 4A. Điểm người chơi tab Daily (follow-up của w21-6)

Hiện Leaderboard tab "Hằng ngày" chỉ hiện bot + note "hoàn thành Hằng ngày để vào bảng"
(`leaderboard_controller.dart` `dailyBoard()` dùng `includePlayer: false`).

### Code grounding
| Mục | File:line |
|---|---|
| Daily finish + win | `game_controller_scoring.dart:437-475` (`isDaily.value` + `checkEnd()` `:214`) |
| Key daily hiện có | `storage_service.dart` `dailyChLastDone`/`dailyChStreak`/`dailyChBestStreak` (**chưa có score**) |
| Ngày hiệu lực | `game_controller_economy.dart:70` `todayEpochDay` (anti-cheat) |
| Engine LB | `core/leaderboard_engine.dart` `buildLeaderboard(..., includePlayer)` |

### Việc
1. Thêm `StorageKeys.dailyBestScore` — lưu dạng `'<epochDay>|<score>'` (chỉ giữ điểm CỦA NGÀY
   hiện tại; ngày mới → reset).
2. Trong `game_controller_scoring.dart:437-475` (nhánh `isDaily && hasWon`): nếu
   `score.value` > điểm đã lưu của `todayEpochDay` → cập nhật `dailyBestScore`.
3. `LeaderboardController.dailyBoard()`: đọc `dailyBestScore`; nếu cùng ngày → truyền
   `playerScore` thật + `includePlayer: true`; khác ngày/chưa có → giữ `includePlayer: false`.
4. Xoá `dailyBestScore` trong `resetProgress()`.

### Acceptance
- [ ] Hoàn thành Daily → tab Daily hiện dòng "BẠN" với điểm vừa đạt, xếp đúng hạng.
- [ ] Sang ngày mới (todayEpochDay đổi) → điểm daily reset, người chơi ẩn lại tới khi chơi.
- [ ] `dailyBestScore` chỉ tăng (giữ điểm cao nhất trong ngày); dùng `todayEpochDay` (anti-cheat).
- [ ] `resetProgress()` xoá key. `flutter analyze` 0.

## 4B. i18n tên thế giới (key đã có, chỉ chưa wire)

### Phát hiện
- `world_name_1..10` **đã tồn tại cho cả 22 ngôn ngữ** trong `app_translations.dart`
  (vd `_en` ~`:309`, `_vi` ~`:731`, …) **NHƯNG code KHÔNG dùng** — đang hiển thị hardcode
  `WorldConfig.name` (`levels.dart:364-374`, English).

### Việc (nhỏ)
1. Thêm getter: `String get displayName => 'world_name_$index'.tr;` vào `WorldConfig`
   (giữ `name` English làm fallback/debug).
2. Đổi các nơi hiển thị tên TG sang `displayName`:
   - `world_map_screen.dart` (banner tiêu đề thế giới)
   - `level_select_screen.dart:~80`
   - `game_screen.dart:~43` (nếu hiện tên TG)
3. Kiểm key `world_name_*` đủ 22 ngôn ngữ (nếu thiếu ngôn ngữ nào → bổ sung; phần lớn đã có).

### Acceptance
- [ ] Đổi ngôn ngữ → tên 10 thế giới đổi theo (không còn hardcode English ở mọi locale).
- [ ] Ngôn ngữ chưa dịch tên TG → fallback English, không lộ raw key `world_name_3`.
- [ ] `app_translations_test` vẫn pass (≥79% khác English). `flutter analyze` 0.

## Lưu ý
- 4B rủi ro rất thấp (chỉ wire `.tr`); 4A đụng nhẹ scoring path — test kỹ nhánh daily.
- Liên quan: [[i18n-extra-merge]], [[daily-challenge-subsystem]], [[reset-permanent-controllers]].
