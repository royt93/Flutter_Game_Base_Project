# I5 — Undo miễn phí 1 lần/màn

**Epic:** Meta/retention · **SP:** 2 · **Pri:** P1 · **Deps:** none

## Mục tiêu
Mỗi màn cho phép 1 lần undo không trừ vào `undoCount` (booster đã mua) — giảm friction cho người chơi mới, không phá kinh tế booster vì chỉ 1 lần/màn.

## Vì sao
Undo hiện luôn trừ `undoCount`, khiến người chơi hết booster ngại thử nghiệm nước đi. Cho 1 lần miễn phí/màn tăng cảm giác "an toàn để thử" mà không làm booster mất giá trị (từ lần 2 trở đi vẫn trừ như cũ).

## Acceptance criteria
- [ ] Lần `useUndo()` đầu tiên trong 1 màn không trừ `undoCount` dù còn 0 hay dương
- [ ] Lần `useUndo()` thứ 2 trở đi trong cùng màn trừ `undoCount` bình thường (nếu 0 thì không undo được, như hiện tại)
- [ ] Bắt đầu màn mới (`startLevel`) hoặc chơi lại màn hiện tại reset lại quyền free-undo
- [ ] UI booster undo hiển thị đúng (không bắt buộc đổi UI nếu free-undo không cần icon riêng — xác nhận qua test, không suy đoán)
- [ ] `flutter analyze` 0 lỗi, test cũ liên quan undo vẫn xanh

## Subtasks (gợi ý file)
- `lib/presentation/controllers/game_controller.dart` — thêm field `bool _freeUndoUsedThisLevel = false`, reset trong `startLevel(...)`, kiểm tra/set trong `useUndo()` trước khi gọi `activeGame.undo()` và trừ `undoCount`.
- `test/` — thêm test: gọi `useUndo()` lần 1 với `undoCount = 0` vẫn undo được; gọi lần 2 cùng màn với `undoCount = 0` thì không undo được.

## Ghi chú kỹ thuật
Không cần persist free-undo qua `SharedPreferences` — chỉ là state trong-phiên-chơi (reset mỗi `startLevel`), giống cách `undo()` hiện tại dùng snapshot single-step trong-phiên.

DoD chung: ../README.md.
