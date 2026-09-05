---
id: FEAT-07
title: Daily Login & Streak Calendar (7/30 ngày)
type: feature
priority: P1
effort: M
source: cả agy và claude-CLI đều đề xuất
---

## Vì sao cần
`StreakCounter` (UI) và `nowMsClamped()`/`todayEpochDayClamped()`
(`lib/core/utils/clamped_clock.dart`, chống gian lận chỉnh giờ) đã tồn tại sẵn
riêng lẻ, nhưng chưa có 1 service nối 2 thứ này thành tính năng "điểm danh
hàng ngày" hoàn chỉnh — pattern gần như bắt buộc ở casual game.

## Đề xuất phạm vi
1 service theo dõi: ngày điểm danh gần nhất (dùng `todayEpochDayClamped()`),
số ngày liên tiếp hiện tại, trạng thái claim từng ngày trong chu kỳ 7 ngày,
logic reset streak khi bỏ lỡ 1 ngày. UI lịch 7 ngày dùng chung style
`PanelCard`/`BadgeDot` đã có.

## Acceptance criteria
- [ ] Bỏ lỡ 1 ngày → streak reset về ngày 1 đúng logic.
- [ ] Chỉnh lùi giờ máy không cho phép claim lại ngày đã qua (tận dụng `ClampedClock`).
