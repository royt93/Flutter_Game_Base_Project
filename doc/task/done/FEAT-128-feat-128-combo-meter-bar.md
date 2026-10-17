---
id: FEAT-128
title: ComboMeterBar — Thanh HUD đo nhịp combo tăng nhiệt kèm rung chuyển tầng
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 7)
---

## Vì sao cần
Trong game casual (match-3, bubble shooter, endless runner), combo meter liên tục phản ánh chuỗi hành động đúng nhịp của người chơi. Khi combo lên các mốc cao (x2, x4, x8), thanh đổi màu nhiệt (cyan -> lime -> gold -> orange -> magenta), rung nảy nhẹ và toả hào quang, mang lại cảm giác hưng phấn cao và thôi thúc duy trì nhịp độ.

## Đề xuất phạm vi
Widget `ComboMeterBar` hiển thị:
- Thanh tiến độ combo dạng capsule với gradient đổi màu động theo tầng multiplier (`1x`, `2x`, `3x`, `4x`, `5x+`).
- Hiệu ứng rung nảy nhẹ (`squash-stretch` hoặc `CurvedAnimation` với `NeonTheme.curvePop`) mỗi khi bước sang tầng mới.
- Nhãn text nhân số điểm (`x2`, `x4`...) hiển thị nổi bật ở đầu/cuối thanh.
- Hỗ trợ Reduced Motion: bỏ qua rung nảy, chỉ đổi màu và tiến độ mượt mà.
- Widget thuần dữ liệu: caller sở hữu logic tính combo và decay theo thời gian, widget chỉ nhận `comboCount`, `multiplier`, `progress` (0.0..1.0), `maxCombo`.

## Yêu cầu kiểm thử
- [x] **Unit test**: Dải màu `comboTierColor` khác nhau từ 1x..5x và clamp từ 5x; validate `multiplier >= 1`, `progress` 0.0..1.0 hữu hạn, `height`/`width` dương.
- [x] **Widget test**: Tăng tầng combo nảy rồi về 1.0; mount, cùng tầng, và giảm tầng không nảy; Reduced Motion bỏ nảy; nhãn `xN`, độ rộng fill theo progress, semantics, dispose giữa chừng không lỗi.
- [x] **Showcase test**: Nút "Combo +" tăng progress, đầy thì lên tầng x2; "Drop combo" về x1.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] `AnimatedBuilder` cho hiệu ứng nảy, `RepaintBoundary` quanh thanh; controller dispose khi unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
