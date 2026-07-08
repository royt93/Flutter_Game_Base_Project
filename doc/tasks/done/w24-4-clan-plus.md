---
id: w24-4-clan-plus
title: Clan content sâu hơn — đóng góp từ side-mode
wave: 24
phase: 4
status: done
owner: claude
created: 2026-07-08
---

## Hướng đã chọn: "đóng góp từ side-mode"
Backlog liệt kê 3 hướng: Clan vs Clan / chat-emote tất định / đóng góp từ side-mode. Đọc
`clan_controller.dart` + `clan_engine.dart` trước thì thấy **Clan vs Clan đã được implement từ
W23 "sâu hơn"** (BXH `buildClanLeague`, thưởng top-3 `claimLeagueReward`, UI trong
`clan_screen.dart`) — dòng ghi chú Wave 24 bị lệch thực tế code. Chat-emote tất định là hệ mới
hoàn toàn (không sửa gap nào có sẵn) → trái nguyên tắc "chiều sâu > bề rộng" của Wave 25. Vậy
chỉ còn "đóng góp từ side-mode" khớp đúng khung: campaign đang là nguồn đóng góp DUY NHẤT
(`ClanController.addContribution` chỉ được gọi từ nhánh campaign-win của
`game_screen_controller.dart`), trong khi side-mode (Endless/Boss/Survival/...) chơi xong không
đóng góp gì cho clan — một gap thật trong hệ đã có, sửa rẻ hơn nhiều so với dựng hệ mới.

## Việc đã làm
- `lib/core/clan_engine.dart`: thêm `kClanPointsForSideModeWin = 10` (điểm cố định, thấp hơn
  campaign `clanPointsForWin` để campaign vẫn là nguồn chính).
- `lib/presentation/controllers/clan_controller.dart`: thêm `addSideModeContribution()`, tái
  dùng logic persist chung với `addContribution` qua helper riêng `_addPoints` (tránh trùng code
  ghi tuần/lifetime). Cùng bộ đếm tuần (`clanPointsWeek`) + lifetime (`clanContribLifetime`) với
  campaign — không thêm storage key mới nên không cần sửa `resetProgress`/`resetState` (đã cover
  sẵn qua field hiện có).
- `lib/presentation/controllers/game_screen_controller.dart`: hook `addSideModeContribution()`
  vào nhánh `else` (side-mode) của `_onGameEnd`, chỉ khi `result == 'win'` — đặt tách biệt hoàn
  toàn khỏi `consumeLife()` / `isSideMode` gate của win-streak/unlock, không đụng
  [[side-mode-isolation]].
- UI: thêm dòng chú thích `clan_goal_hint` dưới goal card trong `clan_screen.dart` để người chơi
  hiểu vì sao đóng góp tăng cả khi không chơi campaign.
- i18n: `clan_goal_hint` vào `_extraEn`/`_extraVi`, bản dịch 20 ngôn ngữ ở map mới
  `_w24bByLang` (đặt tên khác `_w24ByLang` theo yêu cầu — tránh đụng ký hiệu với task W24 khác
  đang chạy song song), merge sau `_w252ByLang` trong `keys`.

## Anti-exploit / cô lập
- Không có claimable reward MỚI trong task này (chỉ thêm nguồn NẠP vào bộ đếm có sẵn) → không
  phát sinh guard-key mới; guard-key hiện có của `claimWeeklyReward`/`claimLeagueReward` (ghi
  `rewardWeekRx`/`leagueRewardWeekRx` TRƯỚC khi cộng xu) không đổi, vẫn đúng thứ tự.
- Không thêm persisted key mới → không cần sửa `resetProgress()`; test xác nhận
  `resetProgress()`/`resetState()` vẫn đưa contribution từ side-mode về 0 (dùng field sẵn có).
- Test riêng xác nhận side-mode contribution KHÔNG đụng `winStreak`/`unlockedLevel`/`lives`.

## Kết quả
- `flutter analyze`: **0 issues**.
- `flutter test --exclude-tags slow`: **969 passed**, 0 failed (thêm 6 test case mới +
  1 assertion trong widget test cũ; không regression).
- Test mới trong `test/w23_6_clan_test.dart` (group "W24.4 — đóng góp từ side-mode"): cộng dồn
  đúng bộ đếm tuần/lifetime, side-mode + campaign cộng chung 1 trục, không đụng
  win-streak/unlock/lives, `resetState()` + `resetProgress()` đưa về 0, side-mode contribution
  đủ để đạt mục tiêu tuần và claim thưởng đúng anti-farm (claim 2 lần → lần 2 trả 0).
- Không cần device (thuần data/controller, không đụng engine).
