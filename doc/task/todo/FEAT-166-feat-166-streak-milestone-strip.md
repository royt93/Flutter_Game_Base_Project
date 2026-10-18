---
id: FEAT-166
title: StreakMilestoneStrip — Dải mốc streak dài hạn (3/7/14/30 ngày) kèm trạng thái nhận
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Retention & Progression UI (Wave 16)
---

## Vì sao cần
`DailyLoginCalendarWidget` chỉ bao quát chu kỳ 7 ngày và `StreakCounter` chỉ hiện số ngày. Người chơi cần thấy các mốc streak dài hạn kế tiếp và phần thưởng của từng mốc để có lý do duy trì chuỗi.

## Đề xuất phạm vi
Widget `StreakMilestoneStrip` hiển thị:
- Danh sách mốc `StreakMilestone(days, rewardLabel, icon?)`, đã sắp tăng dần, ít nhất 1 mốc.
- `currentStreak`: mốc đã đạt, mốc kế tiếp (nhấn mạnh) và mốc chưa đạt.
- `claimedDays`: mốc đã nhận; mốc đạt nhưng chưa nhận có CTA `onClaim(days)` do caller xử lý.
- Cuộn ngang lazy khi nhiều mốc; không bị cắt khi textScale 2.0.
- Presentation-only: caller sở hữu streak, thời gian và việc cấp thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: mốc không rỗng, `days > 0`, tăng nghiêm ngặt, không trùng; `currentStreak >= 0`; `claimedDays` chỉ chứa mốc tồn tại và đã đạt; `ArgumentError` runtime.
- [ ] **Widget test**: chưa đạt mốc nào, giữa các mốc, đạt chưa nhận, đã nhận, nhiều mốc cuộn ngang, claim callback, chặn nhấn đúp, semantics từng mốc, 320dp + textScale 2.0, RTL thật.
- [ ] **Integration test (Device)**: claim mốc qua caller seam trên thiết bị thật; kiểm tra lại serial và foreground trước khi chạy.
- [ ] **Golden test**: `runGoldenMatrix` các trạng thái trên × 7 biến thể, viewport 390×844, baseline từ Linux + Flutter 3.35.1.
- [ ] **Interruption test**: đổi `currentStreak` giữa lúc cuộn không mất vị trí hoặc phát callback sai.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: `ScrollController` được dispose, không còn ticker sau unmount.
- [ ] **Frame rate / Jank test**: FrameTiming khi cuộn 30 mốc (profile thiết bị thật), ghi rõ giới hạn engine timing.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Mốc vừa đạt có nhịp nhấn nhẹ một lần; `reducedMotion` tắt hiệu ứng; dùng `ListView.builder` lazy.
