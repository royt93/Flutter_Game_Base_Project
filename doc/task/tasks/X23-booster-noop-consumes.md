# X23 — Swap cùng-ô và Shuffle no-op vẫn trả `true` → tiêu booster mà bàn không đổi

**Epic:** E6 Hardening · **SP:** 2 · **Pri:** Should · **Mức:** P2
**Deps:** — · **Liên quan:** [[F10]]
**Trạng thái:** ✅ Done (2026-08-11)

## Bug
Hợp đồng giữa `GameController` và `PopStarGame` là: booster chỉ bị trừ khi
game trả `true`. Đúng khuôn ở `useBomb`/`useRainbow`/`useSwap`:

```dart
if (!activeGame!.triggerSwap(row1, col1, row2, col2)) return;   // không trừ
swapCount.value--;
```

Hai hàm dưới vi phạm hợp đồng đó — trả `true` cả khi không đổi gì:

### A. Swap một ô với chính nó
`triggerSwap()` (`pop_star_game.dart:1219-1235`) không check
`(row1,col1) != (row2,col2)`. Arm Swap → chọn 1 gem → chọn lại **đúng gem
đó**: animation lật chạy, grid không đổi, nhưng `swapCount--` và
`totalBoostersUsed++`.

Đây là thao tác người chơi rất dễ làm *do nhầm* (bấm 2 lần vào cùng ô vì
tưởng lần đầu chưa ăn), nên nó không phải edge case lý thuyết.

### B. Shuffle không có gì để trộn
`shuffleBoard()` (`pop_star_game.dart:1828-1874`) không yêu cầu ≥2 ô movable,
cũng không kiểm tra permutation có khác trạng thái cũ. Với 0 hoặc 1 ô
movable, hàm vẫn set animation, gọi `_checkEnd()`, trả `true` → `shuffleCount--`.

Kịch bản: bàn gần hết, còn 1 gem không khoá cùng vài obstacle, không nhóm hợp
lệ nào. Người chơi bấm Shuffle hy vọng cứu bàn → mất booster, bàn y nguyên,
vẫn kẹt.

Case B đau hơn A vì nó xảy ra **đúng lúc người chơi tuyệt vọng nhất**.

## Vì sao Should (không Must)
Không hỏng dữ liệu, không farm được — chỉ mất booster của người chơi. Nhưng
diff rất ngắn và nó là loại bug bị đánh giá rất tệ trong review store.

## User story
*As a* người chơi *I want* booster chỉ bị trừ khi nó thật sự thay đổi bàn
*so that* tôi không mất đồ vì một thao tác vô hiệu.

## Acceptance criteria
- [x] `triggerSwap(r, c, r, c)` trả `false`; `swapCount` không đổi;
      `totalBoostersUsed` không đổi; không `_saveUndo()`.
- [x] Bàn chỉ còn ≤1 ô movable → `shuffleBoard()` trả `false`; `shuffleCount`
      không đổi; không animation.
- [x] Bàn có ≥2 ô movable nhưng hoán vị ra **đúng** trạng thái cũ → retry tối
      đa 3 lần rồi trả `false`; không tiêu booster cho bàn không đổi.
- [x] Shuffle/swap bình thường vẫn hoạt động như cũ.
- [x] Test: `test/game/booster_noop_test.dart` (file mới, 5 case X23).
- [ ] ~~"không `_checkEnd()`"~~ — **AC này viết sai, đã bỏ.** Xem dưới.

## Đã sửa
1. `triggerSwap` — guard `if (row1 == row2 && col1 == col2) return false;`
   đặt **trước** `_saveUndo()`.
2. `shuffleBoard` — tính `movable` trước mọi side effect;
   `if (movable.length < 2)` → bail. Chuyển `recordingValid = false` và
   `_saveUndo()` xuống sau khi đã chắc chắn có thay đổi.
3. So trạng thái màu trước/sau khi trộn; giống hệt thì trộn lại tối đa 3 lần
   rồi bail. Giới hạn để không loop vô hạn khi mọi ô xáo được đều cùng màu.
4. Doc comment trên cả 2 hàm ghi rõ hợp đồng "trả `false` = không tiêu
   booster" — đó chính là điều khiến 2 chỗ này bị viết sai từ đầu.

## Sửa sai của chính spec này
AC ban đầu yêu cầu nhánh bail-out **không** gọi `_checkEnd()`. Làm đúng vậy
thì `boss_tile_widget_test.dart` đỏ — cụ thể là case regression *chống
softlock* của [[I29]]: bàn chỉ còn boss tile (0 ô movable), Shuffle là đường
kích hoạt chuỗi `decay-on-stuck` giảm HP boss dần thay vì kết thúc màn.

Bỏ `_checkEnd()` ở nhánh đó = người chơi kẹt cứng trên bàn toàn boss tile.

Bản cuối **vẫn gọi `_checkEnd()`** trước khi trả `false`. Điều này đúng cả về
ngữ nghĩa: Shuffle là hành động "tôi kẹt rồi" của người chơi, đánh giá lại
trạng thái bàn là phản hồi đúng — chỉ là không được tính tiền. Đã ghi lý do
thành comment tại chỗ.

Bài học: guard "no-op thì bail sớm" phải phân biệt **side effect tính tiền**
(phải bỏ) với **side effect an toàn** (phải giữ).

## Kiểm chứng
Tạm gỡ cả 3 guard → 3 test đỏ.

DoD chung: `../README.md`.
