# G3 — Bloom/rim động cho nút + HUD

**Epic:** Neon/Glow · **SP:** 3 · **Pri:** Could · **Deps:** —

## Mục tiêu
Nút chính (PLAY, Next…) và vài phần HUD có **viền glow nhịp thở** (bloom lên-xuống
chậm) để "sống" hơn, không tĩnh.

## Vì sao
Điểm nhấn neon tinh tế trên nền candy; hút mắt vào CTA chính (PLAY).

## Acceptance criteria
- [ ] PLAY (Home) có glow nhịp thở nhẹ, chậm (~1.5–2s/chu kỳ), không nhấp nháy gắt.
- [ ] Áp chọn lọc (CTA chính), KHÔNG mọi nút (tránh rối).
- [ ] Tắt sạch khi rời màn; không tốn perf (1 controller/nút).

## Subtasks (gợi ý file)
1. Tạo wrapper `PulseGlow` (AnimatedBuilder + `NeonTheme.glow` biến thiên blur/alpha).
2. `lib/presentation/screens/home_screen.dart`: bọc PLAY bằng `PulseGlow`.
3. (Tùy chọn) coin chip khi +xu nhấp 1 nhịp.

## Ghi chú kỹ thuật
Chỉ animate `boxShadow` (blur/alpha) — rẻ. Dùng `RepaintBoundary`. Tiết chế: 1–2 chỗ.

DoD chung: `../README.md`.
