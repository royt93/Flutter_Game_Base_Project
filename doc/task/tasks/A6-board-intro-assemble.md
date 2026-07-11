# A6 — Board intro assemble

**Epic:** Animation · **SP:** 3 · **Pri:** Could · **Deps:** —

## Mục tiêu
Đầu mỗi màn, các ô rơi vào vị trí theo kiểu so le (staggered) từ trên xuống rồi
settle nảy nhẹ, thay vì hiện sẵn tức thì.

## Vì sao
Mở màn sống động, báo hiệu "ván mới bắt đầu", rẻ mà tạo cảm giác chỉn chu.

## Acceptance criteria
- [ ] Vào màn: ô xuất hiện lần lượt theo cột/hàng với delay nhỏ + rơi vào (MoveEffect).
- [ ] Khoá input tới khi intro xong (~0.6–1s).
- [ ] Không phá logic tap/pop sau intro; retry cũng chạy intro.
- [ ] 60fps.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: `_rebuildBoard` (hoặc bản intro) đặt block ở vị trí
   trên-màn rồi `MoveToEffect` về cell với delay theo (r,c); set `_animating` trong intro.
2. Gọi intro ở `onLoad` + khi `startLevel`/`again`.
3. Cân thời lượng để không làm chậm nhịp vào màn.

## Ghi chú kỹ thuật
Delay so le: `delay = (r + c) * 0.02` chẳng hạn. Dùng `EffectController(startDelay:)`.
Tận dụng `_animating` để chặn tap trong intro.

DoD chung: `../README.md`.
