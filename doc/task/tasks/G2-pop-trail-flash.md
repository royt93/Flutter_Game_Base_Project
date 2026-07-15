# G2 — Trail sáng + flash combo khi nổ to

**Epic:** Neon/Glow · **SP:** 3 · **Pri:** Should · **Deps:** A1

## Mục tiêu
- Ô nổ để lại **vệt sáng** ngắn (streak) theo hướng bay của hạt.
- Nổ nhóm lớn / combo cao → **flash** toàn màn rất nhẹ (chớp trắng-màu ~80ms).

## Vì sao
Mãn nhãn, nhấn pha nổ lớn; bổ trợ particle hiện có.

## Acceptance criteria
- [x] Mỗi hạt/ô nổ có trail mờ dần (không chỉ chấm tròn).
- [x] Flash chỉ khi vượt ngưỡng (nhóm ≥ N hoặc combo ≥ x). Rất nhẹ, không chói.
- [x] Cap số hiệu ứng/frame; 60fps.

## Rà soát checkbox (2026-07-13)
- `lib/game/pop_star_game.dart:1002+` `_spawnBurst`: `ComputedParticle` vẽ
  `trailLen`/đường mờ theo hướng bay (không chỉ chấm tròn).
- Ngưỡng flash: `_bigGroupThreshold = 6`, `_bigComboThreshold = 2.5`
  (dòng ~424-425) → `controller.triggerFlash()`.
- `_FlashOverlay` (`game_screen.dart:405-427`): `Tween(begin: 0.18, end: 0.0)`
  đúng cap alpha ≤0.18 theo ghi chú kỹ thuật, `ValueKey(tick)` nên các lần
  trigger không cộng dồn sáng.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart` `_spawnBurst`: đổi `CircleParticle` → particle có
   trail (ComputedParticle vẽ đường mờ) hoặc thêm `ScalingParticle` kéo dài.
2. Flash: overlay `Container` màu alpha thấp fade nhanh khi vượt ngưỡng (ở game_screen
   Stack) hoặc `RectangleComponent` full-screen trong Flame.
3. Ngưỡng + cooldown tránh spam flash.

## Ghi chú kỹ thuật
Trail bằng `ComputedParticle` (tự vẽ theo progress) rẻ hơn nhiều sprite. Flash alpha
≤0.18 để không gắt trên nền sáng.

DoD chung: `../README.md`.
