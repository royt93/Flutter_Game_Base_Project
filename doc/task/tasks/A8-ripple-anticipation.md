# A8 — Ripple chạm + anticipation squash

**Epic:** Animation · **SP:** 3 · **Pri:** Could · **Deps:** —

## Mục tiêu
- **Ripple**: sóng tròn lan ra tại điểm ngón chạm mỗi lần tap.
- **Anticipation**: ô trong nhóm co nhẹ (squash) ~40ms TRƯỚC khi nổ, rồi mới bung —
  tạo "lấy đà" cho pop.

## Vì sao
Phản hồi chạm cao cấp; anticipation làm pop "nặng tay" hơn (nguyên tắc animation 12).

## Acceptance criteria
- [ ] Mỗi tap → ripple ngắn tại vị trí chạm (kể cả tap không tạo nhóm).
- [ ] Nhóm hợp lệ: co nhẹ trước rồi mới scale-up→biến mất (chuỗi rõ, tổng vẫn ~pop hiện tại).
- [ ] Không tăng đáng kể độ trễ cảm nhận; 60fps.

## Subtasks (gợi ý file)
1. Ripple: overlay/painter tại `game_screen` nhận vị trí chạm từ `onTapUp`, vẽ vòng
   lan + mờ (~0.3s). Hoặc `ParticleSystemComponent` ring trong Flame.
2. `lib/game/pop_star_game.dart` `_clearAndCollapse`: thêm bước squash (`ScaleEffect.to(0.85)`
   ngắn) trước SequenceEffect pop hiện có.

## Ghi chú kỹ thuật
Anticipation cực ngắn để không làm chậm nhịp. Ripple nên nhẹ (alpha thấp) trên nền
sáng để không rối.

DoD chung: `../README.md`.
