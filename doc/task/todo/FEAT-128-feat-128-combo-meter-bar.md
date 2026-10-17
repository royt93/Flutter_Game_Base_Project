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
- [ ] **Unit test**: Kiểm tra tính toán dải màu theo multiplier, validate `progress` trong khoảng 0.0..1.0 và `multiplier >= 1`.
- [ ] **Widget test**: Kiểm tra tăng tầng combo kích hoạt animation rung nảy, kiểm tra nhãn multiplier hiển thị đúng, Reduced Motion dừng hiệu ứng rung.
- [ ] **Showcase test**: Tích hợp thanh combo vào showcase với nút tăng combo và reset, cập nhật UI chính xác.
- [ ] **Physical integration**: Kiểm tra hiển thị và phản hồi mượt trên thiết bị vật lý thật (Pixel 7 Pro / S24U), không dùng simulator.

## Hiệu năng & Animation
- [ ] Dùng `AnimatedBuilder` và `RepaintBoundary` cô lập vùng thanh combo, tránh rebuild widget cha.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
