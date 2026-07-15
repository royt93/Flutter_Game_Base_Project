# A7 — Slow-mo + camera zoom-punch combo lớn

**Epic:** Animation · **SP:** 5 · **Pri:** Could · **Deps:** F1, A1

## Mục tiêu
Khi nổ cực lớn / combo cao: khựng thời gian rất ngắn (slow-mo) + camera zoom-punch
(phóng nhẹ vào tâm rồi trả về) tạo cảm giác "đã".

## Vì sao
Nhấn mạnh khoảnh khắc đỉnh, thưởng thị giác cho pha chơi hay.

## Acceptance criteria
- [x] Chỉ kích khi vượt ngưỡng (vd nhóm ≥8 hoặc combo ≥ x3) — KHÔNG mọi lần.
- [x] Slow-mo rất ngắn (~120–200ms) rồi trả tốc độ thường; không làm chậm nhịp chơi.
- [x] Zoom-punch nhẹ (scale ≤1.06) ease về; không lệch hit-test tap sau đó.
- [x] Có thể tắt qua Settings (reduce-motion) — không bắt buộc nhưng nên. — `StorageKeys.reduceMotion` + `SwitchListTile` mới trong `settings_screen.dart` (title `'reduce_motion'.tr`, đã có sẵn bản dịch mọi ngôn ngữ); `pop_star_game.dart` đọc qua getter `_reduceMotion` gate cả 3 hiệu ứng "thêm": `_maybeTriggerPunch`/slow-mo (A7), `_maybeTriggerShake` (A1), `_spawnShimmer` (G8) — một cờ, mọi call site liên quan (2026-07-14).

## Rà soát checkbox (2026-07-13)
- `lib/game/pop_star_game.dart`: `_punchGroupThreshold = 8`, `_punchComboThreshold = 3.0`, `_punchCooldownDur = 1.0` (chặn spam) — khớp ngưỡng dòng 13.
- `_slowMoDur = 0.15` (150ms, trong khoảng 120–200ms yêu cầu), áp dụng qua `super.update(_slowMoTimer > 0 ? dt * _slowMoTimeScale : dt)` rồi tự trả về dt thường khi timer hết.
- Zoom-punch triển khai bằng `ScaleEffect.to(Vector2.all(1.06), ...)` trên từng block còn sống (không phải `camera.viewfinder.zoom` — comment trong code giải thích camera zoom không khả thi vì board add trực tiếp vào game, không qua `camera.world`) → tránh đúng rủi ro lệch hit-test mà task lo ngại.
- Grep `reduce_motion`/`reduceMotion` ngoài file dịch: không có toggle thật trong `settings_screen.dart`/`storage_service.dart` — mục này để ngỏ (không bắt buộc).

## Subtasks (gợi ý file)
1. `lib/game/pop_star_game.dart`: hạ `timeScale`/nhân dt tạm trong cửa sổ ngắn (nếu
   Flame hỗ trợ) hoặc điều tiết qua controller; zoom = `camera.viewfinder.zoom` tween.
2. Ngưỡng kích + cooldown tránh spam.
3. Đảm bảo `cellAt` vẫn đúng khi zoom (reset zoom trước khi nhận tap hoặc bù toạ độ).

## Ghi chú kỹ thuật
DỄ LỐ — giữ hiếm + ngắn. Nếu zoom gây lệch tap, chỉ zoom `world` khi `_animating`
(không nhận input lúc đó) và trả về trước khi mở input.

DoD chung: `../README.md`.
