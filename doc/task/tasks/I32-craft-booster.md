# I32 — Craft Booster (đổi gem thừa lấy booster)

**Epic:** Gameplay depth · **SP:** 5 · **Pri:** Should · **Deps:** không

## Mục tiêu
Cuối màn thắng, nếu bàn còn sót lại các nhóm nhỏ (size 2-3, không đủ pop hết,
xem `_checkEnd`/`checkEnd`), quy đổi tổng số cell còn sót thành 1 loại
"craft point" hiển thị ở màn kết quả; đủ ngưỡng thì đổi trực tiếp lấy 1
booster ngẫu nhiên (bomb/shuffle/undo) thay vì chỉ mất trắng. Khuyến khích
người chơi chấp nhận dọn bàn không tối ưu thay vì luôn cố "perfect clear".

## Vì sao
Hiện tại cell còn sót lại khi thắng màn không có giá trị gì (chỉ
`clearBoardBonus` thưởng khi bàn trống hẳn — xem `lib/data/levels.dart`).
Điều này vô tình phạt kép người chơi mới (vừa không được bonus, vừa cảm giác
lãng phí nước đi cuối). Biến "rác" thành tài nguyên booster tái chế đúng tinh
thần thưởng tận dụng, không cần hệ thống điểm/tiền tệ mới — dùng lại 3 loại
booster count đã có.

## Acceptance criteria
- [ ] `lib/logic/pop_collapse.dart` hoặc file mới `lib/logic/craft_points.dart`:
      hàm pure `int craftPointsForRemainingCells(List<List<int?>> grid)` —
      đếm cell còn khác `null` và không phải obstacle/boss tile
      (`isBossTileId`), chia cho 1 hằng số (ví dụ mỗi 4 cell = 1 craft point,
      làm tròn xuống).
- [ ] `GameController.checkEnd(...)`: khi thắng (không phải
      `clearBoardBonus` full-clear), gọi hàm trên với `colorGrid` cuối cùng
      (cần `PopStarGame` expose `colorGrid` tại thời điểm `checkEnd` — đã có
      sẵn field public); nếu craft points ≥ ngưỡng (ví dụ 3), random 1 trong
      3 loại booster (`bombCount`/`shuffleCount`/`undoCount`) +1 qua
      `_grant(...)` helper đã có trong `game_controller.dart`.
- [ ] UI: dialog kết quả thắng (`GameScreen`/`WinDialog` hiện có) thêm 1 dòng
      hiển thị "+1 <tên booster>" kèm icon khi có craft reward; ẩn hoàn toàn
      nếu không đủ ngưỡng (không hiện "0 craft points" gây rối mắt).
- [ ] i18n đủ 22 locale cho dòng thông báo craft reward.
- [ ] Test pure: `craftPointsForRemainingCells` — board trống → 0; board có
      N cell thường → đúng công thức chia làm tròn xuống; board có cell boss
      tile không tính vào craft points.
- [ ] Test `GameController`: thắng màn với bàn còn đủ ngưỡng craft point →
      đúng 1 trong 3 booster count tăng thêm 1; thắng màn full-clear (0 cell
      còn) → không cộng craft (đã có `clearBoardBonus` riêng, không cộng
      trùng).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `_grant(RxInt count, String key, int amount)` đã tồn tại trong
  `game_controller.dart` (dùng cho comeback bonus) — tái dùng thẳng, không
  viết lại logic cộng + lưu storage.
- Random chọn loại booster: dùng `Random` instance sẵn có kiểu seed-based nếu
  cần deterministic trong replay (xem `I28`), nhưng craft reward chỉ xảy ra ở
  thời điểm `checkEnd` (không phải trong lúc pop), không ảnh hưởng
  `colorGrid` — không bắt buộc phải seed theo `PopStarGame._rng`, dùng
  `Random()` thường là đủ vì không tác động tính xác định của replay.
- Không cộng craft point khi `isReplay == true` (giống nguyên tắc "replay chỉ
  xem, không phát thưởng thật" đã áp dụng ở gift/power tile theo `I28`).

DoD chung: `../README.md`.
