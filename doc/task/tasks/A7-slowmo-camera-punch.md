# A7 — Slow-mo + camera zoom-punch combo lớn

**Epic:** Animation · **SP:** 5 · **Pri:** Could · **Deps:** F1, A1

## Mục tiêu
Khi nổ cực lớn / combo cao: khựng thời gian rất ngắn (slow-mo) + camera zoom-punch
(phóng nhẹ vào tâm rồi trả về) tạo cảm giác "đã".

## Vì sao
Nhấn mạnh khoảnh khắc đỉnh, thưởng thị giác cho pha chơi hay.

## Acceptance criteria
- [ ] Chỉ kích khi vượt ngưỡng (vd nhóm ≥8 hoặc combo ≥ x3) — KHÔNG mọi lần.
- [ ] Slow-mo rất ngắn (~120–200ms) rồi trả tốc độ thường; không làm chậm nhịp chơi.
- [ ] Zoom-punch nhẹ (scale ≤1.06) ease về; không lệch hit-test tap sau đó.
- [ ] Có thể tắt qua Settings (reduce-motion) — không bắt buộc nhưng nên.

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: hạ `timeScale`/nhân dt tạm trong cửa sổ ngắn (nếu
   Flame hỗ trợ) hoặc điều tiết qua controller; zoom = `camera.viewfinder.zoom` tween.
2. Ngưỡng kích + cooldown tránh spam.
3. Đảm bảo `cellAt` vẫn đúng khi zoom (reset zoom trước khi nhận tap hoặc bù toạ độ).

## Ghi chú kỹ thuật
DỄ LỐ — giữ hiếm + ngắn. Nếu zoom gây lệch tap, chỉ zoom `world` khi `_animating`
(không nhận input lúc đó) và trả về trước khi mở input.

DoD chung: `../README.md`.
