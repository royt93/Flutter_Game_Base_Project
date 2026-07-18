# I31 — Auto-solve Ghost Hint (gợi ý xem trước bằng ghost overlay)

**Epic:** Gameplay depth · **SP:** 5 · **Pri:** Should · **Deps:** không

## Mục tiêu
Khi người chơi bấm nút "Hint" (nếu chưa có, thêm nút mới cạnh booster bar),
tìm nhóm gem có thể pop điểm cao nhất hiện tại trên `colorGrid` và hiển thị
ghost overlay (viền sáng nhấp nháy quanh các cell của nhóm đó ~1.5s) thay vì
tự động pop hộ. Giới hạn số lần dùng/màn để tránh làm mất thử thách.

## Vì sao
`I4-predictive-hint.md` đã có "predictive hint" (xem trước điểm nhóm khi
đang tap), nhưng đó là phản hồi thụ động theo vị trí tay đang chạm, không chủ
động gợi ý nước đi tốt nhất khi người chơi bí. Đây là tính năng khác: chủ
động quét toàn bàn tìm nước tối ưu — giúp giữ chân người chơi mới ở các world
khó (10-11 màu) mà không phá vỡ gameplay bằng auto-play thật.

## Acceptance criteria
- [ ] `lib/logic/` thêm hàm pure `List<Point<int>>? bestGroupHint(List<List<int?>> grid)`:
      dùng lại `findConnectedGroup` (`lib/logic/pop_detector.dart`) quét mọi
      cell chưa duyệt, bỏ qua boss tile (`isBossTileId`, `lib/logic/boss_tile.dart`)
      và obstacle (xem `lib/logic/obstacle.dart`), trả về nhóm có size lớn
      nhất (dùng `scoreForGroup` từ `lib/data/levels.dart` để so sánh nếu
      cần tie-break theo điểm thay vì size thô); trả `null` nếu không còn
      nhóm ≥2 (board stuck, xem `hasAnyMovableGroup`).
- [ ] `GameController`: `RxInt hintCount` (số lượt hint còn lại/màn, ví dụ
      khởi tạo 3 mỗi lần `startLevel`) — không cần persist qua `StorageKeys`
      (reset mỗi màn, giống tinh thần `undoCount` per-run chứ không phải
      per-day).
- [ ] `PopStarGame` (`lib/game/pop_star_game.dart`): method `showHint()` gọi
      `bestGroupHint(colorGrid)`, nếu có kết quả thì set 1 field
      `List<Point<int>>? _hintCells` + `Timer` tự xoá sau 1.5s; `render()`
      hoặc 1 `Component` overlay vẽ viền nhấp nháy quanh các cell trong
      `_hintCells` (tái dùng pattern glow đã có ở `G1-group-glow-pulse`).
      Không tự pop — người chơi vẫn phải tap thủ công.
- [ ] UI: nút Hint trong booster bar ở `GameScreen`, disable khi
      `hintCount.value == 0`; hiện số lượt còn lại như các booster khác.
      Không tính hint vào `totalBoostersUsed` (không phải booster tiêu hao
      tài nguyên lâu dài, không ảnh hưởng achievement).
- [ ] i18n đủ 22 locale cho label nút + tooltip hết lượt.
- [ ] Test pure: `bestGroupHint` — board có nhiều nhóm kích thước khác nhau
      trả đúng nhóm lớn nhất; board toàn obstacle/boss trả `null`; board rỗng
      trả `null`; board có đúng 1 nhóm ≥2 trả đúng nhóm đó.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `findConnectedGroup(grid, row, col)` trả nhóm size ≥1 — caller (như hàm mới
  này) phải tự lọc `length >= 2` trước khi coi là ứng viên hợp lệ.
- Độ phức tạp: quét toàn bàn O(rows*cols) với 1 `Set<Point>` visited để không
  duyệt lại cell đã thuộc nhóm khác — bàn tối đa 11x12 nên chi phí không đáng
  kể, không cần tối ưu thêm.
- Tránh đụng `I4` (`PredictiveHint`/tương tự trong `pop_star_game.dart`) —
  đặt tên field/method khác (`_hintCells` vs field hiện có của I4) để không
  xung đột.

DoD chung: `../README.md`.
