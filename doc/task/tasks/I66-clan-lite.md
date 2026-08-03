# I66 — Clan Lite

**Epic:** Meta/retention · **SP:** 8 · **Pri:** Could · **Deps:** không

## Mục tiêu

1 "clan" cố định duy nhất (không chọn/tạo clan, không backend) gồm người
chơi + 1 nhóm thành viên NPC tĩnh. Mỗi tuần, tổng đóng góp gem-pop của cả
clan (NPC + người chơi) hướng tới 1 mục tiêu chung (`clanGoalTarget`); đủ
thì nhận thưởng xu 1 lần/tuần. Ngoài ra có bảng xếp hạng đóng góp trong
tuần giữa các thành viên ("Clan Standings") và 2 mốc thành tựu lifetime
theo tổng đóng góp cả đời.

## Vì sao

Đóng lại 7 key i18n đã tồn tại nhưng chưa có logic backing (xác nhận qua
audit round 4): `clan_title`, `clan_goal`, `clan_goal_hint`, `clan_league`,
`ach_desc_clanContribTotal`, `ach_clan_contrib1_t`, `ach_clan_contrib2_t`.
Khác I50 Weekly Goal Card (cá nhân, không so sánh với ai) — I66 thêm lớp xã
hội (so với thành viên NPC) mà không cần backend thật, tái dùng đúng
offline-leaderboard pattern đã dùng ở 4 nơi khác (`lib/logic/leaderboard.dart`
— daily challenge, gauntlet, weekly featured, friend compare).

## Acceptance criteria

- [ ] `lib/data/clan.dart` mới (pure logic, giống `lib/data/weekly_goal.dart`):
  ```dart
  const int clanGoalTarget = 2000;
  const List<String> kClanMemberNames = [/* 6 tên NPC cố định */];
  int clanBotContributionForWeek(int weekIndex, int botIndex); // seeded
      // Random(weekIndex * 97 + botIndex), trả 150-399
  int clanPoolTotal(int weekIndex, int playerContribution);
      // = playerContribution + tổng clanBotContributionForWeek mọi botIndex
  ```
  Tái dùng `weekIndexForEpochDay` từ `weekly_goal.dart` (import, không copy).
- [ ] `GameController` thêm `RxInt clanContribWeek` (reset theo tuần) và
  `int clanContribTotal` (lifetime, không reset, lưu storage). Cả 2 cộng
  dồn tại đúng hook `registerPop()` đã gọi `addWeeklyGoalProgress(groupSize)`
  — thêm 1 lệnh gọi song song `addClanContribution(groupSize)`.
- [ ] Tuần đổi (`currentWeekIndex != StorageKeys.clanGoalWeek` đã lưu) →
  reset `clanContribWeek = 0`, reset trạng thái đã nhận thưởng tuần, lưu
  tuần mới. Dùng lại đúng `currentWeekIndex` đã tính cho I50 (không tính
  riêng 2 lần).
- [ ] Khi `clanPoolTotal(currentWeekIndex, clanContribWeek.value) >=
  clanGoalTarget`: hiện nút nhận thưởng 150 xu, đánh dấu
  `StorageKeys.clanGoalClaimedWeek = currentWeekIndex`, chặn nhận 2 lần
  cùng tuần (test riêng, mirror I50).
- [ ] Màn/dialog mới hiển thị: thanh tiến độ pool (`clan_goal`/
  `clan_goal_hint`), nút nhận thưởng, và bảng `clan_league` — dùng thẳng
  `LeaderboardEntry`/`buildLeaderboard`/`playerRank` từ
  `lib/logic/leaderboard.dart`, xếp theo đóng góp tuần này (bot dùng
  `clanBotContributionForWeek`, player dùng `clanContribWeek.value`). Theo
  "Dialog pattern" trong CLAUDE.md (`NeonDialog.overlay`, không dùng
  `Get.dialog`/`showDialog`).
- [ ] `lib/data/achievements.dart`: thêm `AchievementMetric.clanContribTotal`
  vào enum + đúng 2 achievement (không phải 5 mốc như các metric khác —
  khớp đúng số title key đã có sẵn):
  - id `clan_contrib1`, threshold 2000, coinReward 100, titleKey
    `ach_clan_contrib1_t`, descKey `ach_desc_clanContribTotal`.
  - id `clan_contrib2`, threshold 10000, coinReward 400, titleKey
    `ach_clan_contrib2_t`, descKey `ach_desc_clanContribTotal`.
  - `_checkAchievements()` thêm nhánh so `clanContribTotal` với 2 ngưỡng
    trên, theo đúng pattern các metric khác.
- [ ] `StorageKeys` mới: `clanContribWeek`, `clanContribTotal`,
  `clanGoalWeek`, `clanGoalClaimedWeek`.
- [ ] Unit test `test/data/clan_test.dart`: `clanBotContributionForWeek`
  xác định (cùng input → cùng output); `clanPoolTotal` cộng đúng; test
  riêng chặn nhận thưởng 2 lần cùng tuần (mirror `weekly_goal_test.dart`).
- [ ] i18n: 4 key `clan_title`/`clan_goal`/`clan_goal_hint`/`clan_league`
  đã đủ 22 locale sẵn — không cần thêm. 6 tên NPC là proper noun, không
  cần key dịch riêng.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Không tạo hệ thống chọn/tạo clan — chỉ 1 clan cố định toàn cục, đúng
  tinh thần "Lite". Nhiều clan thật (cần backend) là feature khác hẳn,
  không mở rộng từ đây.
- `clanContribWeek` là bộ đếm MỚI, tách biệt hoàn toàn khỏi
  `weeklyGoalProgress` (I50) dù cùng hook điểm — 2 mục tiêu có
  target/lifecycle khác nhau (300 vs 2000), không dùng chung 1 biến.

DoD chung: `../README.md`.
