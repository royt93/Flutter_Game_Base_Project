# I47 — Mirror Mode

**Epic:** Gameplay depth · **SP:** 8 · **Pri:** Could · **Deps:** không

## Mục tiêu

Thêm 1 side-mode mới `GameMode.mirrorMode`: bàn được sinh **đối xứng
gương** theo trục dọc — nửa bên phải luôn là ảnh gương của nửa bên trái
(cùng màu tại vị trí đối xứng). Không giới hạn thời gian, không target
score cố định — chơi tới khi bàn kẹt hoặc dọn sạch, ghi nhận điểm cao
nhất (best score) riêng biệt, theo đúng khuôn Endless/Zen (không có
target/stars).

## Vì sao

7 mode hiện có (campaign, timeAttack, zen, endless, dailyChallenge,
puzzleLab, bossRush — chưa tính prestige) đều sinh bàn ngẫu nhiên hoàn
toàn hoặc theo level cố định. Mirror Mode tạo 1 ràng buộc cấu trúc mới lên
chính bố cục bàn (không phải luật pop) — buộc người chơi nhận diện pattern
đối xứng, một góc nhìn puzzle khác hẳn Puzzle Lab (I42, bàn thủ công) hay
Endless (I39, ngẫu nhiên thuần). Tái dùng gần như toàn bộ hạ tầng
mode-mới đã chứng minh ở Endless/Boss Rush.

## Acceptance criteria

- [ ] Thêm `GameMode.mirrorMode` vào enum; `GameController.startMirrorMode()`
  theo đúng khuôn reset của `startEndless`/`startBossRush` (score/starsEarned/
  ended/cleared/resetCombo/activeGame=null/_freeUndoLeft/hintCount/
  movesUsed/_collectInitial).
- [ ] Sinh bàn: với `cols` bất kỳ, cột `c` và cột `cols-1-c` phải luôn
  cùng màu tại mọi hàng (`colorGrid[r][c] == colorGrid[r][cols-1-c]`).
  Nếu `cols` lẻ, cột giữa tự đối xứng với chính nó (không ràng buộc gì
  thêm). Áp dụng ngay từ lúc khởi tạo — **không** áp dụng lại sau mỗi lần
  gravity/collapse (nghĩa là sau khi người chơi pop, bàn có thể mất tính
  đối xứng — đây là hành vi mong đợi, không phải bug: tính đối xứng chỉ
  là điều kiện khởi tạo/mỗi bàn mới, không phải bất biến xuyên suốt).
- [ ] Khi bàn dọn sạch hoặc hết cách đi (`stuck`), sinh bàn mới đối xứng
  kế tiếp (giống `_nextEndlessBoard`) — không tính target score, không
  `clearBoardBonus` giữa các bàn (nhất quán với Endless).
- [ ] Khi hết cách đi hẳn (không sinh bàn mới được nữa vì đã dùng hết
  lượt — spec này không giới hạn số bàn, chơi vô hạn tới khi người chơi
  chủ động thoát hoặc board đầu tiên bị kẹt mà không dọn sạch), gọi
  `controller.checkEnd(false)`.
- [ ] Ghi nhận best score riêng (`StorageKeys.mirrorModeBestScore`),
  cập nhật khi `score.value` hiện tại vượt best cũ lúc `checkEnd`.
- [ ] Entry point: thêm 1 nút trong modes dialog (`home_screen.dart`),
  màu chưa dùng trong hàng hiện có, dẫn thẳng tới `GameScreen` (theo
  đúng khuôn timeAttack/zen/endless — **không** cần lobby riêng như Boss
  Rush vì không có khái niệm "chuỗi/stage" hiển thị).
- [ ] i18n: các key mới cho tên mode/nhãn best score, đủ 22 locale.
- [ ] Unit test hàm sinh bàn đối xứng thuần (`test/data/mirror_board_test.dart`
  hoặc tương đương trong `lib/data/`): verify đối xứng đúng với `cols`
  chẵn/lẻ, `rows`/`colorCount` hợp lệ, deterministic theo seed.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Hàm sinh bàn đối xứng nên là pure function mới trong `lib/data/`
  (vd `lib/data/mirror_board.dart`, hàm `List<List<int>>
  generateMirrorBoard(int rows, int cols, int colorCount, Random rng)`),
  tách biệt khỏi `PopStarGame` — theo đúng nguyên tắc kiến trúc "pure
  logic tách khỏi Flame engine" của dự án.
- `checkEnd()` trong `GameController` cần thêm 1 nhánh mới trong khối
  `if (mode.value != GameMode.campaign)` (giống nhánh `endless`/`timeAttack`)
  để lưu best score qua `StorageKeys.mirrorModeBestScore` — tái dùng
  đúng pattern `coins.value += x; StorageService.to.setInt(...)` đã dùng
  khắp `game_controller.dart`.
- `PopStarGame._checkEnd()` thêm nhánh `GameMode.mirrorMode` mirror chính
  xác cấu trúc nhánh `GameMode.endless` đã có (dùng
  `generateMirrorBoard` thay vì random thuần tại `_nextEndlessBoard`).
- Không cần `bossHp`/obstacle/gift đặc biệt gì thêm — bàn Mirror Mode là
  bàn thường, chỉ khác ở bước sinh màu ban đầu.

DoD chung: `../README.md`.
