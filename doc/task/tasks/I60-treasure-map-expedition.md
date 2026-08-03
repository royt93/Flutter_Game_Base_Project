# I60 — Treasure Map & Expedition

**Epic:** Gameplay depth + retention · **SP:** 5 · **Pri:** Could
· **Deps:** I33 (Daily Modifier Gauntlet)

## Mục tiêu

Mỗi 24h xuất hiện 1 "bản đồ kho báu" gồm 5 chặng nối tiếp, mỗi chặng có
luật biến tấu riêng (vd chỉ pop nhóm ≥5, hoặc giới hạn 10 nước đi). Tiêu
1 "Bản đồ" (nhận từ streak/weekly goal) để thám hiểm, hoàn thành cả 5
chặng nhận rương chứa skin/frame cosmetic độc quyền.

## Vì sao

Veteran player đã xong 220 level campaign cần thử thách chiến thuật sâu
hơn Gauntlet (I33, chỉ 1 modifier/ngày) — Treasure Map là chuỗi 5 chặng
tăng dần, tạo lý do quay lại mỗi ngày để săn cosmetic hiếm riêng cho mode
này.

## Acceptance criteria

- [ ] Mở rộng `GauntletModifier` (`lib/data/gauntlet_modifiers.dart` dòng
  8-28) thêm 2 field mới `int? moveLimit` và `int? minGroupSize` — dùng
  lại đúng class này cho cả Gauntlet lẫn Treasure Map thay vì tạo class
  song song.
- [ ] Áp `minGroupSize`: nhóm pop nhỏ hơn ngưỡng bị chặn tap (không pop,
  có feedback nhẹ) — logic mới hoàn toàn, hiện `pop_detector.dart` không
  có khái niệm ngưỡng kích thước nhóm tối thiểu.
- [ ] Áp `moveLimit` tái dùng `movesUsed` (`game_controller.dart` dòng
  84, tăng dòng 1317) — khi `movesUsed.value >= moveLimit`, kết thúc
  chặng như hết bàn (thắng/thua theo target đạt được hay chưa), tương tự
  logic `_underMoveLimitBonus()` (dòng 1482-1484) nhưng thành điều kiện
  kết-thúc-cứng thay vì chỉ tính bonus sao.
- [ ] `TreasureMapController` mới (GetX, cô lập theo đúng pattern
  `BossRushController`) — `stageIndex.obs` (1-5), seed ngày sinh qua
  `_todayEpochDay()`, mỗi chặng dùng
  `generateDailyChallengeGrid(seed + stageIndex)` + 1 `GauntletModifier`
  cố định theo chặng (độ khó tăng dần 1→5).
- [ ] `StorageKeys.treasureMapCount` (số "Bản đồ" đang có, int) — nhận từ
  streak (I48)/weekly goal (I50) claim reward, tiêu 1 khi bắt đầu thám
  hiểm; hết bản đồ thì không thám hiểm được (không ép mua bằng coin, giữ
  "không P2W").
- [ ] Rương thưởng cuối chặng 5: cosmetic độc quyền riêng cho mode này —
  thêm vào `board_frames.dart`/`mascot_skins.dart` với điều kiện mở khoá
  mới, hoặc `StorageKeys.treasureMapCompleted` (boolean) nếu đơn giản
  hơn việc mở rộng enum unlock.
- [ ] Bỏ giữa chừng (thua 1 chặng) → mất lượt thám hiểm đó, không cộng
  dồn tiến độ, phải dùng "Bản đồ" khác để thử lại từ chặng 1.
- [ ] Unit test mở rộng `test/data/gauntlet_modifiers_test.dart` cho
  `moveLimit`/`minGroupSize`; mở rộng `test/logic/pop_detector_test.dart`
  cho ngưỡng `minGroupSize` chặn nhóm nhỏ đúng cách.
- [ ] i18n toàn bộ text bản đồ/chặng/rương, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Gap xác nhận: hiện KHÔNG có cơ chế enforce move-limit cứng hay
  min-group-size nào đang chạy (chỉ có `_underMoveLimitBonus()` tính
  bonus sao, không chặn game) và `gauntlet_modifiers.dart` chưa có field
  nào cho 2 luật này — đây là logic mới thật sự, không phải ghép nối
  thuần tuý.
- Tái dùng generator + seed pattern y hệt Daily Challenge/Gauntlet
  (`generateDailyChallengeGrid`, `Random(seed)`) — chỉ khác ở việc cộng
  `stageIndex` vào seed để mỗi chặng có bàn khác nhau nhưng vẫn
  deterministic cùng ngày.
- Nếu triển khai leaderboard riêng cho mode này, đặt tên file theo đúng
  convention `{mode}_leaderboard_bots.dart` (không bắt buộc trong
  acceptance criteria).

DoD chung: `../README.md`.
