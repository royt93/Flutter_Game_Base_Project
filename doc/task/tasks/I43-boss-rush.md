# I43 — Boss Rush (chuỗi màn boss liên tiếp)

**Epic:** Gameplay depth (big feature) · **SP:** 13 · **Pri:** Could · **Deps:** không

## Mục tiêu
Thêm 1 chế độ riêng "Boss Rush": chơi liên tiếp 1 chuỗi bàn có boss tile
(`lib/logic/boss_tile.dart`) rút từ các world đã unlock, không cho dùng
booster (hoặc giới hạn số lượng mang theo), mỗi bàn thắng mới được đi tiếp,
thua/hết mạng thì dừng chuỗi — ghi nhận "chuỗi dài nhất" (số bàn liên tiếp đã
qua) làm thước đo thành tích riêng, tách khỏi campaign 220 level.

## Vì sao
`boss_tile.dart` (`BossTileSpec`, `placeBossTile`, `chipAdjacentBossTiles`,
`decayBossTilesOnStuck`) hiện chỉ xuất hiện rải rác trong các level campaign
thường (I29) — chưa có chế độ nào tập trung thử thách xoay quanh riêng cơ chế
này. Boss Rush tạo 1 "cao độ kỹ năng" mới cho người chơi đã thông thạo cơ chế
boss tile, tái dùng gần như toàn bộ hạ tầng đã có (bàn, boss logic, target
score) mà không cần thiết kế nội dung mới — chỉ cần 1 lớp điều phối chuỗi
bàn + màn hình riêng.

## Acceptance criteria
- [ ] `lib/data/boss_rush.dart` (mới): hàm pure
      `PopLevel bossRushLevelForStage(int stage, int maxUnlockedWorld)` —
      chọn 1 `PopLevel` gốc từ world ngẫu nhiên (seed theo `stage`, không
      cần lưu RNG state phức tạp — dùng `Random(stage)` cục bộ) trong số
      world đã unlock, ép buộc luôn có boss tile (áp `bossTargetMultiplier =
      1.5` như convention hiện có ở `lib/data/levels.dart` cho các bàn có
      boss) và độ khó tăng nhẹ theo `stage` (ví dụ `targetScore` nhân thêm
      `1 + stage * 0.05`, trần ở 1 mức hợp lý để không vô hạn tăng).
- [ ] `GameController`/`lib/presentation/controllers/boss_rush_controller.dart`
      (mới, controller riêng theo đúng pattern `GameScreenController` —
      không nhồi vào `GameController` chung để tránh phình file, đúng
      convention "single file, no part splitting" nhưng KHÔNG áp dụng cho
      controller mới vì đây là 1 domain khác hẳn campaign): quản lý
      `stage` (RxInt, bắt đầu 1), `bossRushBestStreak` (đọc/ghi qua
      `StorageKeys.bossRushBestStreak` mới), `livesRemaining` (RxInt, ví dụ
      bắt đầu 1 mạng — thua là dừng chuỗi ngay, đơn giản nhất; có thể để dư
      địa thêm mạng sau nếu cân bằng cần).
- [ ] Trong Boss Rush: KHÔNG cho dùng booster từ kho chung (`bombCount`,
      `shuffleCount`, `undoCount` của `GameController`) — chế độ này test kỹ
      năng thuần, tránh người chơi dùng hết booster tích trữ để đi vô hạn.
      Đây là quyết định thiết kế rõ ràng, không phải thiếu sót — ghi chú
      trong UI cho người chơi biết trước khi vào.
- [ ] Thắng 1 bàn → `stage++`, dùng `bossRushLevelForStage(stage, ...)` tạo
      bàn kế tiếp ngay (không có màn nghỉ dài, tiết tấu nhanh theo đúng tinh
      thần "rush"). Thua hoặc bàn bị stuck
      (`hasAnyMovableGroup` false và chưa đạt target) → dừng chuỗi, so
      `stage - 1` (số bàn đã qua) với `bossRushBestStreak`, cập nhật nếu cao
      hơn, thưởng coin theo luỹ tiến (ví dụ `stage * 50`, tái dùng cùng đơn vị
      coin với `_grant()` helper trên `GameController` nếu truy cập được từ
      controller mới, hoặc gọi qua `Get.find<GameController>()`).
- [ ] `PopStarGame` cần nhận được world/level xác định từ `boss_rush.dart`
      — dùng lại constructor hiện có (level id ảo hoặc field mới `PopLevel`
      trực tiếp thay vì id tra cứu trong `kLevels`, xem cách `presetGrid`
      test đã bơm level tuỳ ý vào game để tránh cần thêm 220+N level giả vào
      `kLevels`).
- [ ] UI: 1 màn hình mới `lib/presentation/screens/boss_rush_screen.dart`
      hiện `stage` hiện tại, `bossRushBestStreak`, nút bắt đầu/tiếp tục;
      màn kết thúc hiện số bàn đã qua + coin thưởng.
- [ ] i18n đủ 22 locale.
- [ ] Test pure: `bossRushLevelForStage` — luôn trả bàn có boss tile hợp lệ
      (`colorCount`/`rows`/`cols` trong khoảng hợp lệ theo world nguồn),
      cùng `stage` cùng `maxUnlockedWorld` → luôn ra kết quả giống hệt
      (deterministic), `targetScore` tăng dần theo `stage` nhưng có trần.
- [ ] Test controller: thua ở stage N → `bossRushBestStreak` cập nhật đúng
      `N-1` nếu cao hơn giá trị cũ, KHÔNG cập nhật nếu thấp hơn; booster
      count không bị trừ trong Boss Rush (không gọi được `useBomb`/
      `useShuffle`/`useUndo` trong chế độ này, hoặc UI ẩn hẳn nút booster).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- Đây là task lớn (SP 13) — nên chẻ nhỏ: (1) `boss_rush.dart` pure logic +
  test, (2) controller quản lý stage/streak, (3) UI + luồng chơi liên tiếp,
  (4) tích hợp coin thưởng + best streak vào 1 màn hiển thị thành tích chung
  nếu có (`I34-trophy-room.md` có thể hiển thị `bossRushBestStreak` như 1
  chỉ số — không bắt buộc trong scope I43 này, chỉ cần lưu đúng key để I34
  đọc được sau).
- KHÔNG trùng phạm vi với `I27` (Prestige/New Game+ — đã xong, là vòng lặp
  lại toàn bộ campaign với hệ số nhân điểm) — I43 là 1 chế độ chơi riêng
  biệt, ngắn hạn (vài bàn/lượt), không lặp lại 220 level.
- `decayBossTilesOnStuck` cần xác nhận hoạt động đúng khi bàn được tạo từ
  `bossRushLevelForStage` (không phải từ `kLevels` cố định) — vì đây là bàn
  sinh động, kiểm tra kỹ initial state có boss tile không bị đặt ở vị trí
  khiến bàn bất khả thi ngay từ đầu (ví dụ boss tile chiếm hết 1 cột duy
  nhất còn lại).

DoD chung: `../README.md`.
