# G8 — Glow burst ring + idle shimmer sweep

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** A1 (cùng luồng pop)

## Mục tiêu
- **Burst ring**: mỗi lần nổ, 1 vòng sáng bung ra từ tâm nhóm rồi mờ (shockwave).
- **Idle shimmer**: khi bàn rảnh vài giây, 1 tia sáng quét chéo qua các ô (long lanh).

## Vì sao
Mỗi pop mãn nhãn hơn; bàn không "chết" khi người chơi ngập ngừng.

## Acceptance criteria
- [ ] Nổ → ring sáng nở từ tâm (~0.3s) mờ dần; cap số ring đồng thời.
- [ ] Rảnh > X giây → shimmer quét ngang bàn 1 lượt, lặp thưa; dừng khi có tap.
- [ ] 60fps; ring/shimmer nhẹ, không che UI.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart` `_clearAndCollapse`: spawn ring component (CircleComponent
   scale-up + fade) tại tâm nhóm; cap đồng thời.
2. Idle shimmer: timer đếm rảnh (reset khi tap); khi kích → 1 lớp gradient sweep quét
   qua vùng bàn (component/painter) rồi tự gỡ.
3. Tôn trọng `_animating` (không shimmer khi đang diễn hoạt).

## Ghi chú kỹ thuật
Ring = `CircleComponent` viền + `ScaleEffect`+fade, `removeOnFinish`. Shimmer sweep =
1 dải gradient dịch ngang (MoveEffect) clip trong tray. Giữ hiếm/nhẹ.

DoD chung: `../README.md`.
