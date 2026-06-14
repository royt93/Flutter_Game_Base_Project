---
id: w7-battle-pass
title: Battle Pass + nhiệm vụ ngày
wave: 7
status: done
owner: claude
---

# Battle Pass (track thưởng theo cấp) + Nhiệm vụ hằng ngày

> Lý do chọn: vòng lặp ngày rõ ràng "làm nhiệm vụ → lên cấp pass → nhận thưởng".
> Khác daily-reward hiện tại (chỉ điểm danh): đây là MỤC TIÊU CÓ HÀNH ĐỘNG.
> Lưu ý phân biệt rõ với daily reward để không trùng cảm giác.

## Nhiệm vụ ngày (Daily Quests)
- 3 nhiệm vụ/ngày, sinh xác định theo `_todayEpochDay` (seed) để lặp test được.
- Ví dụ: "Thắng 3 màn", "Tạo 5 gem special", "Ghép combo ≥5", "Dọn 10 obstacle".
- Theo dõi qua các stat đã có trong `GameController` (totalWins, bestCombo...) +
  bộ đếm phiên mới (specialsCreated, obstaclesCleared cộng dồn ngày).
- Hoàn thành → +**XP pass**.

## Battle Pass track
- 1 track ~20 cấp, mỗi cấp cần XP tăng dần.
- Mỗi cấp 1 thưởng (xu / booster / shard). (Phiên bản đầu: chỉ track FREE, chưa
  bán premium — giữ offline thuần, monetization để sau.)
- Reset theo mùa (gắn với `w7-seasonal-event` nếu làm sau nó) hoặc theo tháng.

## Dữ liệu / Persist
- `lib/data/battle_pass.dart`: danh sách cấp + thưởng; `dailyQuestsFor(epochDay)`.
- Persist: `bp_xp`, `bp_level`, `bp_claimed_<level>`, `quest_done_<epochDay>_<idx>`,
  `quest_progress_<epochDay>_<idx>`.

## UI
- `battle_pass_screen.dart`: track ngang cuộn được + panel 3 nhiệm vụ ngày.
- Badge Home khi có nhiệm vụ xong / cấp pass chưa nhận.

## Test
- quest sinh xác định theo ngày; tiến trình cộng đúng; lên cấp khi đủ XP;
  claim 1 lần/cấp; sang ngày mới reset nhiệm vụ.

## Trạng thái — ✅ DONE
`data/battle_pass.dart` (9 quest pool, dailyQuests xác định theo epoch-day, 12 tier),
`battle_pass_controller.dart` (XP→level, quest progress/credit, claim 1 lần, reset theo ngày),
hook `recordLevelEnd` ở `game_screen_controller._onGameEnd` (bỏ Endless/Boss),
`battle_pass_screen.dart` (quest + track), entry hàng meta Home (badge khi có tier nhận),
`runMaxCombo` thêm vào GameController cho quest combo, i18n en+vi, reset trong `resetProgress`.
Kết quả: 0 analyzer · test `test/w7_battle_pass_test.dart` (6) pass.
