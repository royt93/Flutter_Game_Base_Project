# I61 — Boss Breakout Event Raid

**Epic:** Gameplay depth (event) · **SP:** 8 · **Pri:** Could
· **Deps:** I29 (Boss Rush), I43 (Boss tile mechanics)

## Mục tiêu

Sự kiện hàng tuần: 1 boss cố định HP cao xuất hiện trên 1 bàn 4x4 lớn,
tự động "ra chiêu" (đóng băng ô ngẫu nhiên/sinh obstacle mới) mỗi vài
nước đi. Người chơi có giới hạn lượt thử/ngày, gây sát thương tích luỹ cả
tuần, nhận thưởng theo bậc tổng sát thương cuối tuần.

## Vì sao

Boss Rush (I29) là chuỗi boss tăng dần độ khó nhưng boss thuần bị động
(chỉ phản ứng khi bị tap cạnh). Raid Event tạo áp lực chiến thuật mới
(boss chủ động phản công), khung thời gian sự kiện hàng tuần tạo nhịp
quay lại đều đặn khác với Boss Rush (chơi bất kỳ lúc nào).

## Acceptance criteria

- [ ] `lib/logic/boss_skill.dart` mới (pure logic) — `BossSkill{skillType,
  triggerEveryNMoves}`, tối thiểu 2 loại skill: đóng băng N ô ngẫu nhiên,
  sinh thêm 1 obstacle mới trên bàn.
- [ ] Hàm pure mới `freezeRandomCells(grid, lockGrid, count, seed)` —
  logic hoàn toàn mới, hiện project chỉ có
  `countdown_lock_tile.dart` xử lý khoá đếm ngược từng ô đơn lẻ, không có
  tiện ích khoá ngẫu nhiên hàng loạt.
- [ ] Kích hoạt skill mỗi N nước đi, dùng lại `registerPop()`/`movesUsed`
  (`game_controller.dart` dòng 1317) làm điểm hook đếm nước đi.
- [ ] Tái dùng cơ chế boss tile hiện có (`lib/logic/boss_tile.dart`):
  `bossTileIdBase = -2000`, `Map<int,int> bossHp`,
  `chipAdjacentBossTiles()` (dòng 73-94) — boss raid là 1 boss tile 4x4 HP
  cao cố định (không scale theo stage như Boss Rush).
- [ ] `RaidBossController` mới (GetX, cô lập — **tách biệt hoàn toàn
  `BossRushController`**, không tái dùng chung vì luật khác nhau: có
  active skill, giới hạn lượt/ngày, lịch sự kiện) — `attemptsRemaining.obs`
  (reset 3/ngày), `totalDamageThisEvent.obs`.
- [ ] Hàm mới `isRaidActive({required int epochDay})` kiểm tra ngày trong
  tuần theo lịch cố định trong code (không có backend/calendar động) —
  vd raid mở thứ 6-Chủ nhật mỗi tuần.
- [ ] `StorageKeys.raidBossAttemptsUsed`, `raidBossTotalDamage`,
  `raidBossEventWeek` (theo đúng pattern rollover tuần của
  `weeklyGoalWeek`) — sang tuần mới reset damage + attempts.
- [ ] Thưởng theo bậc tổng sát thương cuối tuần (coin/cosmetic), chỉ nhận
  1 lần/tuần khi sự kiện kết thúc.
- [ ] Unit test mới `test/logic/boss_skill_test.dart`: skill trigger đúng
  chu kỳ N nước; `freezeRandomCells` khoá đúng số lượng ô, deterministic
  với seed cố định, không khoá ô đã trống/đã khoá.
- [ ] i18n toàn bộ text sự kiện/skill/thưởng, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Gap xác nhận: KHÔNG có cơ chế "boss tự ra chiêu định kỳ" nào tồn tại
  (boss hiện tại hoàn toàn bị động); KHÔNG có tiện ích đóng-băng-hàng-loạt
  ngẫu nhiên; KHÔNG có hạ tầng lên lịch sự kiện theo tuần nào trong
  codebase — cả 3 đều là logic mới thật sự, đây là task SP cao nhất
  trong đợt.
- Cân nhắc scope-reduction nếu SP=8 vượt quá: giảm còn 1 loại skill duy
  nhất (chỉ đóng băng ô) cho bản đầu tiên, bổ sung skill thứ 2 ở task sau
  — ghi rõ quyết định khi triển khai nếu áp dụng.
- `RaidBossController` KHÔNG kế thừa/tái dùng `BossRushController` — 2
  controller độc lập tránh coupling luật chơi khác nhau (I61 có giới hạn
  lượt/ngày + skill chủ động, I29 không có).

DoD chung: `../README.md`.
