# I46 — Wildcard Tile

**Epic:** Gameplay depth · **SP:** 5 · **Pri:** Could · **Deps:** không

## Mục tiêu

Thêm 1 ô đặc biệt "Wildcard" xuất hiện ngẫu nhiên khi khởi tạo board
(campaign, mọi world) — về mặt flood-fill, ô này được coi là khớp với
**bất kỳ màu nào** khi tính nhóm liền kề, nên nó luôn được cuốn theo bất
kỳ nhóm màu ≥2 nào chạm vào nó (không cần cùng màu). Khi bị pop cùng
nhóm, tính điểm như 1 ô bình thường trong nhóm (không có điểm thưởng
riêng).

## Vì sao

Đây là mảnh ghép còn thiếu trong hệ 4 loại ô đặc biệt hiện có: obstacle
(chip durability khi kề pop), gift (mở thưởng khi rơi xuống đáy), boss/
chain (HP/lock chip khi kề pop), power tile (tự kích hoạt hiệu ứng dọn
bàn khi tap). Cả 4 đều **thêm 1 lớp trạng thái/hành vi lên trên** cơ chế
pop gốc — chưa có cái nào **thay đổi chính luật ghép màu** của
`pop_detector.findConnectedGroup`. Wildcard Tile lấp khoảng trống đó,
giúp người chơi "gỡ kẹt" khi bàn có ít lựa chọn nhóm lớn, mà không đụng
tới bất kỳ hệ thống tile nào đã có.

## Acceptance criteria

- [ ] Mã hoá bằng 1 sentinel âm cố định mới **-500** trong `colorGrid`
  (không trùng obstacle/gift/boss/countdown-lock — các dải đã dùng là
  small-negative, `-1000`, `≤-2000`, `≤-1500`).
- [ ] `findConnectedGroup(grid, row, col)` trong `pop_detector.dart`: khi
  duyệt flood-fill từ 1 ô màu thường, ô lân cận có giá trị `-500` được
  coi là "khớp màu" và được thêm vào nhóm (đệ quy tiếp từ ô đó với cùng
  màu gốc) — nhưng khi **bắt đầu** flood-fill trực tiếp từ 1 ô `-500`
  (tap thẳng vào nó khi nó không kề màu nào), nhóm size chỉ gồm chính nó
  (không tự nhân bản thành nhóm giả).
- [ ] Khi 1 ô Wildcard nằm giữa 2 nhóm màu khác nhau không liền kề nhau
  qua đường nào khác ngoài chính nó, nó chỉ nối vào **nhóm được duyệt
  trước** theo thứ tự flood-fill hiện có (không tạo hành vi "nối 2 màu
  khác nhau thành 1 nhóm duy nhất" — flood-fill vẫn chạy đơn hướng theo 1
  màu gốc tại mỗi lần gọi).
- [ ] Sau khi bị pop cùng nhóm, ô biến mất khỏi `colorGrid`
  (`= null`) như ô thường, không sinh hiệu ứng đặc biệt, không cộng điểm
  ngoài công thức `scoreForGroup(n)` hiện có (n đã bao gồm chính ô
  wildcard).
- [ ] Không xuất hiện ở side-mode (chỉ campaign) trong scope spec này.
- [ ] Unit test `test/logic/pop_detector_test.dart` (bổ sung case mới,
  không tạo file riêng vì đây là thay đổi trực tiếp lên
  `findConnectedGroup`): ô wildcard luôn được cuốn theo nhóm màu kề bất
  kỳ; tap thẳng vào wildcard cô lập (không kề màu nào) trả về nhóm size
  1; 2 nhóm màu khác nhau không tự gộp qua 1 wildcard trung gian nếu
  flood-fill gọi theo đúng entry point ban đầu.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Đây là thay đổi **trực tiếp vào `findConnectedGroup`** (không phải một
  lớp bọc ngoài) — cần đọc kỹ implementation hiện tại trước khi sửa để
  đảm bảo không phá vỡ hành vi `color < 0` (loại trừ obstacle/gift/boss
  khỏi flood-fill) đã có: điều kiện match cần phân biệt rõ `-500`
  (wildcard, luôn match) khỏi các giá trị âm khác (luôn không match).
- Sinh ngẫu nhiên: tối đa 1 ô wildcard mỗi board, xác suất thấp (~10%),
  không sinh đè lên vị trí đã có obstacle/gift/boss/lockGrid>0 — kiểm tra
  tại thời điểm khởi tạo board (nơi `_placeBossTileIfNeeded`/obstacle
  spawn hiện chạy).
- `_syncObstacleAndLockBlocks()` cần thêm nhánh set
  `BlockComponent.colorIndex` phù hợp để hiển thị hình ảnh khác biệt cho
  ô wildcard (vd icon ngôi sao) — tái dùng đúng pattern sync hiện có, chỉ
  thêm 1 case mới trong switch/if-chain.
- Không thêm `StorageKeys` mới.

DoD chung: `../README.md`.
