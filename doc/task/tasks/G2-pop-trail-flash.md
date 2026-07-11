# G2 — Trail sáng + flash combo khi nổ to

**Epic:** Neon/Glow · **SP:** 3 · **Pri:** Should · **Deps:** A1

## Mục tiêu
- Ô nổ để lại **vệt sáng** ngắn (streak) theo hướng bay của hạt.
- Nổ nhóm lớn / combo cao → **flash** toàn màn rất nhẹ (chớp trắng-màu ~80ms).

## Vì sao
Mãn nhãn, nhấn pha nổ lớn; bổ trợ particle hiện có.

## Acceptance criteria
- [ ] Mỗi hạt/ô nổ có trail mờ dần (không chỉ chấm tròn).
- [ ] Flash chỉ khi vượt ngưỡng (nhóm ≥ N hoặc combo ≥ x). Rất nhẹ, không chói.
- [ ] Cap số hiệu ứng/frame; 60fps.

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
