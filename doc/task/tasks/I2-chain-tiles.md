# I2 — Color-lock / chain tiles

**Epic:** Gameplay depth · **SP:** 5 · **Pri:** P2 · **Deps:** none

## Mục tiêu
Thêm loại ô "bị xích" (chain): vẫn có màu bình thường và tham gia thị giác bàn cờ, nhưng KHÔNG match được cho tới khi ô cạnh nó bị nổ đủ K lần — khác obstacle (F6a, không màu, không bao giờ match).

## Vì sao
Obstacle hiện tại (`lib/logic/obstacle.dart`) encode bằng giá trị âm (`-durability`) và bị loại hoàn toàn khỏi flood-fill — phù hợp cho "chướng ngại vật" nhưng không đủ cho "ô có màu nhưng tạm khoá", vì flood-fill chỉ so khớp giá trị dương bằng nhau. Cần 1 lớp trạng thái song song để biểu diễn "màu C, khoá K lần" mà không phá encoding hiện có.

## Acceptance criteria
- [x] Có cấu trúc dữ liệu mới (không tái dùng encoding âm của obstacle) biểu diễn số lần khoá còn lại cho từng ô, song song `colorGrid`
- [x] Ô đang khoá (`lock > 0`): bị loại khỏi `findConnectedGroup` (không match được dù cùng màu ô cạnh) nhưng vẫn hiển thị đúng màu gốc trên UI
- [x] Mỗi lần 1 ô cạnh (4-hướng) bị pop, các ô khoá liền kề giảm `lock` đi 1 (tái dùng đúng cơ chế "chip cạnh" đã có ở `chipAdjacentObstacles`, viết hàm tương tự cho lock thay vì durability)
- [x] `lock` về 0: ô hoạt động như ô màu bình thường, tham gia flood-fill ngay lượt kế tiếp
- [x] Gravity/collapse (`applyGravityAndCollapse`) xử lý đúng ô đang khoá (rơi cùng cột như ô thường, không bị bỏ qua)
- [x] Test thuần Dart (không Flutter) cho phần logic khoá/mở khoá trong `lib/logic/`, theo đúng tinh thần layer 1 "no Flutter, no Flame, no GetX"
- [x] `flutter analyze` 0 lỗi — chạy trong phiên 2026-07-14: "No issues found!"
      + `flutter test --exclude-tags slow` 225/225 xanh.

## Rà soát checkbox (2026-07-13)
- `lib/logic/chain_tile.dart`: `chipAdjacentLocks(lockGrid, poppedCells)` —
  cấu trúc `List<List<int>> lockGrid` song song `colorGrid`, dedup qua Set,
  đúng tinh thần `chipAdjacentObstacles` nhưng không tái dùng encoding âm.
- `lib/logic/pop_detector.dart`: `findConnectedGroup`/`hasAnyMovableGroup`
  nhận `lockGrid` optional, loại ô `lockGrid[r][c] > 0` khỏi flood-fill;
  `lock == 0` thì tham gia bình thường (đọc lại mỗi lần gọi, không cần cờ
  riêng).
- `lib/game/pop_star_game.dart`: field `lockGrid` khởi tạo cùng `colorGrid`
  (dòng ~141,194); đồng bộ theo cột trong gravity/collapse (`lockGrid[r][c] =
  b?.lockCount ?? 0`, dòng ~862); `block_component.dart` giữ màu gốc, chỉ vẽ
  thêm số lock (`lockCount`).
- Test thuần logic: `test/logic/chain_tile_test.dart` (chip lock) +
  `test/logic/pop_detector_test.dart` (loại trừ ô khoá khỏi flood-fill) — cả
  hai chỉ import `lib/logic/*`, không đụng Flutter/Flame/GetX runtime dù
  dùng `flutter_test` làm test runner (quy ước sẵn có của repo).
- `flutter analyze`/`flutter test` đã chạy xanh trong phiên 2026-07-14 (xem
  checkbox tương ứng ở trên) — tick.

## Subtasks (gợi ý file)
- `lib/logic/` — thêm file mới (ví dụ `chain_tile.dart`) chứa hàm thuần: `chipAdjacentLocks(lockGrid, poppedCells)` (giảm lock các ô cạnh vừa pop) và điều kiện loại ô khoá khỏi `findConnectedGroup` (có thể sửa `pop_detector.dart` nhận thêm `lockGrid` optional, hoặc để `PopStarGame` lọc trước khi gọi).
- `lib/game/pop_star_game.dart` — thêm field `List<List<int>> lockGrid`, khởi tạo cùng lúc `colorGrid`, đồng bộ theo gravity/collapse (column cùng chỉ số phải rơi cùng lúc với `colorGrid`).
- `lib/data/levels.dart` — cân nhắc thêm `ObjectiveType`/cấu hình mới nếu chain tile gắn với 1 objective riêng, hoặc chỉ là biến thể board-gen cho vài level (quyết định khi implement, không bắt buộc thêm objective type mới nếu chain tile chỉ là "gia vị" trên board chứ không phải điều kiện thắng).
- Test: `test/logic/` file mới, test thuần Dart cho chip-lock + flood-fill loại trừ ô khoá.

## Ghi chú kỹ thuật
Đây là task phức tạp nhất trong nhóm 7 — đụng cả layer 1 (logic thuần) lẫn layer 3 (Flame game, gravity/collapse phải đồng bộ 2 grid song song). Nên tách riêng plan (`EnterPlanMode`) trước khi code, không gộp chung PR với các task nhẹ khác (I11/I5/I13).

DoD chung: ../README.md.
