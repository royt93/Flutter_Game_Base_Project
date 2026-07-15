# A6 — Board intro assemble

**Epic:** Animation · **SP:** 3 · **Pri:** Could · **Deps:** —

## Mục tiêu
Đầu mỗi màn, các ô rơi vào vị trí theo kiểu so le (staggered) từ trên xuống rồi
settle nảy nhẹ, thay vì hiện sẵn tức thì.

## Vì sao
Mở màn sống động, báo hiệu "ván mới bắt đầu", rẻ mà tạo cảm giác chỉn chu.

## Acceptance criteria
- [x] Vào màn: ô xuất hiện lần lượt theo cột/hàng với delay nhỏ + rơi vào (MoveEffect).
- [x] Khoá input tới khi intro xong (~0.6–1s).
- [x] Không phá logic tap/pop sau intro; retry cũng chạy intro.
- [ ] 60fps. (chưa chạy tay trên device, chỉ verify code + test tự động)

## Rà soát checkbox (2026-07-13)
- `_rebuildBoard(animateIntro:)` (`lib/game/pop_star_game.dart` dòng ~1176): block spawn ở `_introStart` (ngoài màn) rồi `MoveToEffect` về `target` với `delay = (r+c) * _introStagger` (0.02s/step), `_introFallDur = 0.35s` → tổng dưới ~1s cho bàn thường.
- `_animating = true` khi `animateIntro`, chỉ mở lại (`_animating = false`) sau `TimerComponent(period: maxDelay + _introFallDur, ...)` — khoá tap đúng tới khi xong.
- Gọi tại `onLoad()` (dòng 205) và cả `again`/retry (dòng ~1069, ~1083) đều `_rebuildBoard(animateIntro: true)` — retry cũng chạy intro.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: `_rebuildBoard` (hoặc bản intro) đặt block ở vị trí
   trên-màn rồi `MoveToEffect` về cell với delay theo (r,c); set `_animating` trong intro.
2. Gọi intro ở `onLoad` + khi `startLevel`/`again`.
3. Cân thời lượng để không làm chậm nhịp vào màn.

## Ghi chú kỹ thuật
Delay so le: `delay = (r + c) * 0.02` chẳng hạn. Dùng `EffectController(startDelay:)`.
Tận dụng `_animating` để chặn tap trong intro.

DoD chung: `../README.md`.
