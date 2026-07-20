# I44 — Time Freeze Tile

**Epic:** Gameplay depth · **SP:** 5 · **Pri:** Could · **Deps:** không

## Mục tiêu

Trong `GameMode.timeAttack`, thỉnh thoảng gắn 1 ô bàn (đang có màu bình
thường) thành "Time Freeze" — tap trực tiếp vào đúng ô đó (không cần gộp
nhóm ≥2) cộng thêm +10 giây vào đồng hồ đếm ngược rồi ô biến mất (rơi
xuống như ô trống bình thường, không để lại gì). Tối đa 1 ô Time Freeze
tồn tại trên bàn cùng lúc. Chỉ xuất hiện ở Time Attack — không đụng
campaign/zen/endless/dailyChallenge/puzzleLab/bossRush.

## Vì sao

`GameScreenController.remainingSeconds` (khởi tạo từ `timeAttackSeconds =
60`, đếm lùi qua `Timer.periodic`) hiện là countdown thuần — không có cơ
chế "cứu giờ" nào, khác Boss Rush (I43, có "chuỗi") hay Puzzle Lab (I42,
không giới hạn giờ). Time Freeze Tile tạo thêm 1 lượt cân nhắc chiến thuật
(tap ô cứu giờ hay pop nhóm điểm cao hơn) mà không cần thêm mode mới, và
tái dùng đúng cơ chế "tag lên ô màu có sẵn, tap trực tiếp kích hoạt" mà
`PowerTileKind` (F5, `lib/logic/power_tile.dart`) đã chứng minh hoạt động
tốt — khác các tile trước đó (I1 gift/-1000, I29 boss/≤-2000, F6a
obstacle/-durability) vốn mã hoá thẳng trong `colorGrid`.

## Acceptance criteria

- [ ] Cơ chế gắn/tap tuân theo đúng pattern power tile: **không** mã hoá
  giá trị âm mới trong `colorGrid` — ô Time Freeze vẫn giữ nguyên
  `colorIndex` bình thường, chỉ gắn thêm 1 field kiểu
  `bool timeFreezeTagged` (hoặc tương đương) trên `BlockComponent`, giống
  cách `_blocks[row][col]?.powerKind = kind` hoạt động.
- [ ] Chỉ gắn tag khi `controller.mode.value == GameMode.timeAttack`; tối
  đa 1 ô được tag tại 1 thời điểm trên toàn bàn.
- [ ] Tap trực tiếp vào ô đã tag (kể cả khi ô đó lẻ loi, nhóm <2) kích hoạt:
  cộng +10s vào `Get.find<GameScreenController>().remainingSeconds.value`,
  ô đó biến mất khỏi bàn (set `colorGrid[r][c] = null`), gravity/collapse
  chạy như bình thường.
- [ ] Tap ô đã tag như 1 phần của nhóm màu ≥2 (pop chung với các ô cùng
  màu xung quanh) **vẫn** kích hoạt hiệu ứng +10s (không yêu cầu tap solo
  mới tính) — tránh gây khó chịu khi người chơi vô tình pop trúng.
- [ ] Không gắn tag/không có hiệu ứng gì ở các `GameMode` khác.
- [ ] Unit test `test/logic/time_freeze_tile_test.dart`: hàm quyết định có
  nên gắn tag lần collapse này không (pure function, seed `Random` cố
  định) — verify tần suất hợp lý, không bao giờ gắn quá 1 ô cùng lúc,
  không gắn khi `mode != timeAttack`.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Vị trí sinh: kiểm tra sau mỗi lần `_collapseAnimated` hoàn tất (giống
  thời điểm `_placeBossTileIfNeeded` được gọi ở Boss Rush) — random 1 ô
  đang có màu hợp lệ (`colorGrid[r][c] != null && colorGrid[r][c]! >= 0`)
  và hiện chưa bị tag bởi bất kỳ cơ chế đặc biệt nào khác (obstacle/gift/
  boss/lockGrid/powerKind) để tránh chồng 2 hiệu ứng lên cùng 1 ô.
  Xác suất thấp (vd 8-12% mỗi lần collapse, tối đa 1 lần mỗi ~5-8 giây
  thực tế) — tinh chỉnh qua playtest, không cần chính xác tuyệt đối ở
  spec này.
- Route tap: thêm nhánh kiểm tra `_blocks[row][col]?.timeFreezeTagged ==
  true` trong `_tryPop`, side-effect (+10s) chạy độc lập với luồng
  score/combo bình thường — không cộng điểm, không tính vào combo.
- `GameScreenController.remainingSeconds` là `RxInt`
  (`game_screen_controller.dart:36`) — `PopStarGame` không giữ tham chiếu
  trực tiếp tới `GameScreenController`, cần `Get.find<GameScreenController>()`
  tại điểm kích hoạt (tương tự cách `PopStarGame` gọi
  `Get.find<BossRushController>().advanceStage()` ở I43).
- Không thêm `StorageKeys` mới — hiệu ứng chỉ trong phạm vi 1 ván, không
  cần lưu trạng thái giữa các lần chơi.

DoD chung: `../README.md`.
