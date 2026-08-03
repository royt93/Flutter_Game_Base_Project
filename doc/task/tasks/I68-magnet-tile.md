# I68 — Magnet Tile

**Epic:** Gameplay depth · **SP:** 5 · **Pri:** Should · **Deps:** không

## Mục tiêu

1 special tile mới cho campaign — Magnet Tile, gắn cố định 1 màu mục tiêu
lúc sinh bàn. Khi bất kỳ đâu trên bàn có 1 nhóm cùng màu mục tiêu bị pop,
Magnet Tile lập tức tự "kích hoạt" (biến mất khỏi bàn, cộng điểm thưởng cố
định), rơi vào collapse như 1 ô vừa pop bình thường.

## Vì sao

Khác Wildcard (I46 — match được mọi màu khi đứng TRONG 1 nhóm được tap) và
Gift (tự mở khi rơi xuống hàng đáy) — Magnet là tile PASSIVE, kích hoạt bởi
hành động Ở NƠI KHÁC trên bàn (không cần tap trúng nó), thưởng người chơi
ưu tiên pop đúng màu mục tiêu trước, thêm 1 lớp chiến thuật chọn thứ tự
pop nhóm màu.

## Acceptance criteria

- [ ] `lib/logic/magnet_tile.dart` mới, theo đúng convention
  `countdown_lock_tile.dart`:
  ```dart
  const magnetTileIdBase = -700; // giữa wildcard (-500) và gift (-1000)

  bool isMagnetId(int? value) =>
      value != null && value <= magnetTileIdBase && value > -800;

  int encodeMagnetTile(int colorIndex) => magnetTileIdBase - colorIndex;

  int magnetColorIndex(int value) => magnetTileIdBase - value;

  /// Trả toạ độ mọi Magnet Tile khớp [poppedColorIndex] trên [grid] — gọi
  /// ngay sau khi 1 nhóm màu bị pop, TRƯỚC khi gravity chạy.
  List<(int, int)> magnetTilesTriggeredBy(
    List<List<int?>> grid,
    int poppedColorIndex,
  );
  ```
- [ ] `pop_star_game.dart`: sau khi `_tryPop` xác định nhóm bị pop (màu
  `poppedColorIndex`), gọi `magnetTilesTriggeredBy(colorGrid,
  poppedColorIndex)`; mọi ô khớp cũng bị xoá khỏi `colorGrid` (set
  `null`), cộng điểm thưởng cố định (hằng số `magnetBonusScore`, vd 50/ô)
  vào cùng đợt điểm, để `_collapseAnimated` xử lý rơi chung với nhóm vừa
  pop (không cần animation riêng).
- [ ] `block_component.dart` thêm overlay Magnet: icon nam châm phủ lên
  màu nền `magnetColorIndex(value)` (đúng màu tile bên dưới).
- [ ] Sinh bàn: tối đa 1 Magnet Tile/màn (giống Countdown Lock), chỉ
  campaign, chỉ xuất hiện từ world đã dùng cho các special tile khác
  (theo danh sách gán tile hiện có trong `levels.dart`/`worlds.dart`),
  tránh spawn trùng ô với obstacle/gift/boss/wildcard/countdown-lock/chain
  đã có trên cùng bàn.
- [ ] `pop_detector.dart`: `findConnectedGroup` bỏ qua id Magnet (không
  tham gia flood-fill trực tiếp, không tap được — giống cách nó đã bỏ qua
  obstacle/gift/boss).
- [ ] Unit test `test/logic/magnet_tile_test.dart`: `magnetTilesTriggeredBy`
  trả đúng toạ độ khi màu khớp, rỗng khi không khớp; nhiều Magnet khác
  màu cùng lúc trên 1 bàn chỉ kích hoạt đúng cái khớp; round-trip
  `encodeMagnetTile`/`magnetColorIndex` cho mọi `colorIndex` 0..7.
- [ ] i18n: kiểm `guide_screen.dart` xem có cần thêm mục giải thích tile
  mới không (theo đúng pattern Wildcard/Countdown Lock đã có), đủ 22
  locale nếu thêm.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- `-700` là khoảng trống thật giữa wildcard (-500) và gift (-1000) — đã
  xác nhận không đụng dải nào (obstacle -1..-9, wildcard -500, gift
  -1000, countdown-lock -1500, boss <= -2000). Biên `> -800` chừa dư
  khoảng 0..99 cho `colorIndex` dù `colorCount` tối đa hiện tại chỉ 8.
- Trigger PHẢI chạy trước gravity trong cùng khung xử lý pop — chạy sau
  thì toạ độ Magnet có thể đã đổi do ô khác rơi xuống trước.
- Magnet bị loại khỏi flood-fill nên không thể tự nằm trong nhóm vừa tap
  — vẫn nên có test rõ ràng để tránh double-score nếu logic thay đổi sau
  này.

DoD chung: `../README.md`.
