# I45 — Countdown Lock Tile

**Epic:** Gameplay depth · **SP:** 8 · **Pri:** Could · **Deps:** không

## Mục tiêu

Thêm 1 loại ô đặc biệt mới xuất hiện ngẫu nhiên ở campaign từ world 4 trở
đi (level ≥61): "Countdown Lock" — hiển thị 1 số đếm ngược (vd 5), giảm 1
mỗi khi người chơi thực hiện 1 lượt tap hợp lệ (bất kể tap trúng ô nào,
không cần kề ô Countdown Lock), **không** giảm theo kiểu "bị pop nhóm màu
kề bên chip 1 durability" như obstacle/boss. Về 0 → ô tự chuyển thành
obstacle thường (durability 1, tức cần 1 lần pop nhóm kề để phá).

## Vì sao

Toàn bộ cơ chế "đếm lùi" hiện có trong game đều gắn với thời gian thực
(Time Attack `remainingSeconds`) hoặc với hành động pop-kề-cạnh (obstacle
durability, boss HP, chain lock count — đều chip khi 1 nhóm màu liền kề bị
pop). Countdown Lock Tile tạo áp lực khác hẳn: "đếm theo số lượt đi", buộc
người chơi phải tính toán trước bao nhiêu nước đi còn lại thay vì chỉ nhắm
trúng ô đó — khác biệt rõ với mọi tile hiện có, tăng chiều sâu chiến thuật
campaign mà không cần thêm mode mới.

## Acceptance criteria

- [ ] Sinh ngẫu nhiên khi khởi tạo board cho các level thuộc world ≥4
  (`level.id > 60`), xác suất thấp (1 ô mỗi board, ~15-20% cơ hội xuất
  hiện) — không sinh ở world 1-3, không sinh ở side-mode
  (timeAttack/zen/endless/dailyChallenge/puzzleLab/bossRush) — chỉ campaign
  thường.
- [ ] Mã hoá bằng dải id âm riêng, **không trùng** obstacle
  (`-durability`, số nhỏ), gift (`-1000`), boss (`≤-2000` từ
  `bossTileIdBase`) — dùng dải mới bắt đầu từ `-1500` giảm dần cho mỗi
  instance, cùng 1 `Map<int,int> countdownRemaining` (giá trị còn lại)
  song song với `colorGrid`, mirror đúng cấu trúc `bossHp`.
- [ ] `pop_detector.dart`: ô Countdown Lock bị loại khỏi flood-fill giống
  obstacle/boss (dùng chung nhánh `color < 0` hiện có, cộng thêm điều kiện
  loại trừ gift/boss như code comment đã cảnh báo).
- [ ] Sau **mỗi lượt tap hợp lệ** của người chơi (tức mỗi lần `_tryPop` xử
  lý xong 1 nhóm ≥2, bất kể nhóm đó có phải Countdown Lock hay không), tất
  cả instance Countdown Lock trên bàn giảm 1 trong `countdownRemaining`.
  Tap không hợp lệ (nhóm <2, ô trống) **không** tính là 1 lượt.
- [ ] Khi `countdownRemaining[id] <= 0`: ô đó chuyển `colorGrid[r][c]` từ
  id âm hiện tại thành `-1` (durability 1, tức 1 obstacle thường theo đúng
  encoding `lib/logic/obstacle.dart`), xoá entry khỏi
  `countdownRemaining`.
- [ ] `_syncObstacleAndLockBlocks()` (hoặc hàm sync tương đương) cập nhật
  hiển thị số đếm ngược lên `BlockComponent` (field mới, vd `int?
  countdownDisplay`) mỗi khi giá trị thay đổi.
- [ ] Unit test `test/logic/countdown_lock_tile_test.dart`: giảm đúng 1
  mỗi lượt tap hợp lệ, không giảm khi tap thất bại (nhóm <2), về 0 chuyển
  đúng thành obstacle durability 1, không đụng tới `bossHp`/gift/lockGrid
  của cùng bàn.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Dải id: instance đầu tiên trên 1 bàn dùng `-1500`, instance kế (nếu
  tương lai cho phép nhiều hơn 1 — spec này chỉ yêu cầu tối đa 1 ô/board
  nên thực tế luôn là `-1500`) sẽ lùi tiếp `-1501`, `-1502`... theo đúng
  khuôn per-instance-id của `bossTileIdBase = -2000`.
- Khác biệt cốt lõi so với obstacle/boss (chip khi có nhóm liền kề bị pop)
  và giống thiết kế counter thời gian thực của Boss Rush/Time Attack (đếm
  không phụ thuộc vị trí): hook điểm giảm đặt ngay sau khi `_tryPop` xác
  nhận 1 lượt tap hợp lệ đã pop xong 1 nhóm (không phải trong
  `chipAdjacentObstacles`/`_chipAdjacentBossTiles`), để tránh nhầm lẫn với
  logic chip-theo-kề đã có.
- File logic mới đề xuất: `lib/logic/countdown_lock_tile.dart` (pure
  Dart, không phụ thuộc Flame/GetX) — hàm
  `int? tickCountdownLockTiles(Map<int,int> countdownRemaining)` trả về id
  vừa hết hạn (nếu có) để `pop_star_game.dart` xử lý chuyển đổi
  `colorGrid`, theo đúng convention tách logic thuần khỏi engine.
- Không thêm `StorageKeys` mới — trạng thái chỉ tồn tại trong phạm vi 1
  ván, không cần lưu.

DoD chung: `../README.md`.
