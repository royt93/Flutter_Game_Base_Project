---
id: FEAT-165
title: XpLevelHeader — Header cấp độ người chơi kèm thanh XP tới cấp kế
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Retention & Progression UI (Wave 16)
---

## Vì sao cần
`LevelUpOverlay` chỉ xuất hiện lúc lên cấp và `RewardTrackRoad` là một đường đi dài. HUD hằng ngày thiếu một header gọn cho biết cấp hiện tại, XP đã có và XP còn thiếu tới cấp kế, nguồn dữ liệu là `PlayerProgressionService` do caller sở hữu.

## Đề xuất phạm vi
Widget `XpLevelHeader` hiển thị:
- Badge cấp `level`, tên/danh hiệu tuỳ chọn.
- Thanh XP `currentXp`/`xpForNextLevel` kèm text caller-formatted.
- Cấp tối đa (`xpForNextLevel == null`): thanh đầy, hiển thị `MAX`.
- `onTap()` tuỳ chọn mở màn thông tin cấp độ của caller.
- Presentation-only: không tính XP, không lưu, không phát level-up.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: `level >= 1`, `currentXp >= 0`, `xpForNextLevel > 0` khi có, `currentXp <= xpForNextLevel`; label không rỗng; `ArgumentError` runtime.
- [ ] **Widget test**: 0 XP, giữa, sát đầy, cấp tối đa, tap, semantics đọc cấp và phần trăm, 320dp + textScale 2.0 gutter 16dp, RTL thật.
- [ ] **Integration test (Device)**: tap header mở màn thông tin cấp độ qua caller seam trên thiết bị thật; kiểm tra lại serial và foreground trước khi chạy.
- [ ] **Golden test**: `runGoldenMatrix` 0/giữa/gần đầy/MAX × 7 biến thể, viewport 390×844, baseline từ Linux + Flutter 3.35.1.
- [ ] **Interruption test**: tăng XP nhiều lần liên tiếp rồi đổi `level` giữa animation không crash, giá trị cuối đúng.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: không còn ticker sau unmount/reduced motion.
- [ ] **Frame rate / Jank test**: FrameTiming khi XP tăng liên tục (profile thiết bị thật), ghi rõ giới hạn của engine timing.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Thanh XP tăng mượt (tái dùng motion token `NeonTheme`); `reducedMotion` nhảy thẳng tới giá trị đích; không phát hiệu ứng khi mount lần đầu.
