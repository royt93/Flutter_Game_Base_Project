# A8 — Ripple chạm + anticipation squash

**Epic:** Animation · **SP:** 3 · **Pri:** Could · **Deps:** —

## Mục tiêu
- **Ripple**: sóng tròn lan ra tại điểm ngón chạm mỗi lần tap.
- **Anticipation**: ô trong nhóm co nhẹ (squash) ~40ms TRƯỚC khi nổ, rồi mới bung —
  tạo "lấy đà" cho pop.

## Vì sao
Phản hồi chạm cao cấp; anticipation làm pop "nặng tay" hơn (nguyên tắc animation 12).

## Acceptance criteria
- [x] Mỗi tap → ripple ngắn tại vị trí chạm (kể cả tap không tạo nhóm).
- [x] Nhóm hợp lệ: co nhẹ trước rồi mới scale-up→biến mất (chuỗi rõ, tổng vẫn ~pop hiện tại).
- [x] Không tăng đáng kể độ trễ cảm nhận; 60fps. Verify tay trên Samsung SM_S928B (2026-07-17): tap liên tục qua nhiều nhóm ở Level 1 (ripple + anticipation squash chạy mỗi tap), `adb logcat -d | grep -i "Choreographer\|skipped\|FATAL"` không có match, cảm nhận input không bị trễ.

## Rà soát checkbox (2026-07-13)
- `handleTap` (`lib/game/pop_star_game.dart`): gọi `_spawnRipple(pos)` ngay sau khi xác định `cell`, TRƯỚC khi kiểm tra pop/power-tile → chạy cho mọi tap hợp lệ kể cả không tạo nhóm.
- `_clearAndCollapse`: mỗi block nổ chạy `SequenceEffect([ScaleEffect.to(0.85, duration: _squashDur=0.04), ScaleEffect.to(1.3, 0.07), ScaleEffect.to(0, duration: _popDur-_squashDur-0.07)])` — co nhẹ 40ms rồi mới bung, tổng thời lượng vẫn giữ `_popDur` (0.16s) như cũ.
- `_spawnRipple`: `_BurstRing` alpha thấp (0.35) tự dọn nhanh (~0.32s), tách khỏi cap `_maxRings` nên không ảnh hưởng hiệu năng khi tap dồn dập.

## Subtasks (gợi ý file)
1. Ripple: overlay/painter tại `game_screen` nhận vị trí chạm từ `onTapUp`, vẽ vòng
   lan + mờ (~0.3s). Hoặc `ParticleSystemComponent` ring trong Flame.
2. `lib/game/pop_star_game.dart` `_clearAndCollapse`: thêm bước squash (`ScaleEffect.to(0.85)`
   ngắn) trước SequenceEffect pop hiện có.

## Ghi chú kỹ thuật
Anticipation cực ngắn để không làm chậm nhịp. Ripple nên nhẹ (alpha thấp) trên nền
sáng để không rối.

DoD chung: `../README.md`.
