# A9 — Xóa "snap" tức thì còn sót ở booster + dialog

**Epic:** Animation · **SP:** 3 · **Pri:** Must · **Deps:** —

## Mục tiêu
Audit toàn game phát hiện các điểm thay đổi state tức thì (0 animation), gây
cảm giác "giật cứng" so với phần còn lại của game (vốn đã animate rất mượt).
Sửa toàn bộ trong một wave:

1. **Undo** (`GameController.undo` → `PopStarGame.undo`): rebuild bàn tức thì
   → dùng lại `_rebuildBoard(animateIntro: true)` (hiệu ứng rơi-vào-vị-trí
   sẵn có lúc vào level) cho cảm giác "hoàn tác = ván bài rơi lại".
2. **Shuffle**: tương tự Undo — `shuffleBoard()` dùng lại `animateIntro: true`.
3. **Swap booster**: đổi màu 2 ô tức thì → thêm `_swapFlip` (lật theo trục Y,
   đổi màu ở giữa chừng bằng `ScaleEffect.to(..., onComplete: ...)` lồng
   trong `SequenceEffect`).
4. **Coin balance** (`CoinChip`): số xu nhảy số tức thì → bọc
   `TweenAnimationBuilder<double>` đếm dần (300ms), theo đúng pattern đã có
   sẵn cho điểm số ở `game_screen.dart`.
5. **Booster count HUD** (`_BoosterButton` trong `game_screen.dart`): số lượng
   booster nhảy tức thì → đếm dần tương tự (250ms).
6. **Shop booster count** (`_BoosterRow` trong `shop_screen.dart`): cùng vấn đề
   → đếm dần (250ms).
7. **Shop buy button**: dùng `GestureDetector` trần (không có phản hồi nhấn) —
   duy nhất trong toàn game không dùng `PressableScale` → đổi sang
   `PressableScale`.
8. **Dialog entrance** (`NeonDialog.overlay`): panel hiện tức thì → bọc
   `TweenAnimationBuilder<double>` scale (0.85→1) + fade (`Curves.easeOutBack`,
   220ms). `Opacity` phải `.clamp(0, 1)` vì `easeOutBack` overshoot ngoài
   [0,1] (Transform.scale để overshoot tự nhiên, không clamp).
9. **Dialog exit / chuyển trạng thái** (`_Overlay` trong `game_screen.dart`):
   chuyển giữa `quit`/`win`/`lose`/`playing` là snap cứng (switch trả widget
   trực tiếp) → bọc `AnimatedSwitcher` (160ms) keyed theo `gsc.ui.value`, tách
   switch cũ thành `_buildFor(ui)`.

## Vì sao
User report cụ thể: bấm booster (vd undo) không có animation. Audit rộng ra
phát hiện đây là một pattern lặp lại (mutate state trực tiếp, bỏ qua bước
animate) ở nhiều chỗ khác — sửa gộp 1 lần để toàn game nhất quán, tránh vá
từng điểm rồi vẫn còn sót chỗ khác.

## Quyết định phạm vi (đã cân nhắc, không code)
- **Settings — đổi locale**: `ChoiceChip`/`RawChip` của Flutter đã tự animate
  transition màu/checkmark khi đổi selection — không cần code thêm (ladder
  rung 3: stdlib/native đã lo).
- **Freeze booster — chỉ báo khi dùng**: `freezeTurnsLeft` là `int` thường
  (không phải `RxInt`) trên component Flame, dựng UI reactive N-lượt-còn-lại
  riêng là over-engineering cho 1 hiệu ứng phụ. Gộp vào hiệu ứng đếm dần của
  booster count (mục 5) làm phản hồi "đã dùng" — coi là đủ.

## Acceptance criteria
- [x] Undo/Shuffle: bàn "rơi vào vị trí" thay vì snap. (verify on-device)
- [x] Swap: 2 ô lật dọc rồi đổi màu, không đổi màu tức thì. (verify code)
- [x] Coin/booster count (HUD + Shop): đếm dần, không nhảy số. (verify on-device)
- [x] Nút mua Shop: có phản hồi scale khi nhấn. (`PressableScale` xác nhận)
- [x] Dialog quit/win/lose: fade+scale vào; chuyển giữa các dialog/về
      playing: cross-fade, không snap. (verify on-device: quit dialog)
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh.

**Bonus fix ngoài scope:** nút Undo HUD không tính free-undo quota
(`_freeUndoLeft`) khi tính enabled/disabled → thêm `forceEnabled` param cho
`_BoosterButton`, expose `GameController.hasFreeUndo` getter.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart` — `undo()`, `shuffleBoard()`, `triggerSwap()`
   + `_swapFlip()`.
2. `lib/presentation/widgets/coin_chip.dart`.
3. `lib/presentation/screens/game_screen.dart` — `_BoosterButton`, `_Overlay`.
4. `lib/presentation/screens/shop_screen.dart` — `_BoosterRow`.
5. `lib/presentation/widgets/neon_dialog.dart` — `overlay()`.

## Ghi chú kỹ thuật
`ScaleEffect.to` hỗ trợ `onComplete` riêng dù nằm trong `SequenceEffect` (xác
nhận trực tiếp từ source `flame` package) — dùng để đổi màu đúng lúc bàn cờ
"lật" ở giữa animation swap, tránh đổi màu sai thời điểm.

DoD chung: `../README.md`.
