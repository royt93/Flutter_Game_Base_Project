---
id: FEAT-08
title: Energy/Lives system tự hồi theo thời gian
type: feature
priority: P1
effort: M
source: agy
---

## Vì sao cần
Cơ chế "tim/năng lượng hồi theo thời gian" là chuẩn mực của casual game
(Candy Crush-style) — package hiện chưa có gì cho việc này dù đã có
`ClampedClock` làm nguồn thời gian đáng tin cậy sẵn.

## Đề xuất phạm vi
1 service: số tim hiện tại, thời gian hồi 1 tim (cấu hình được), tính tim đã
hồi bao nhiêu dựa trên thời gian trôi qua kể từ lần trừ tim gần nhất (dùng
`nowMsClamped()`), API `consumeEnergy()`/`grantInfiniteLives(Duration)`.

## Acceptance criteria
- [ ] Trừ tim → đóng app → mở lại sau X phút → tim tự hồi đúng số lượng tính toán được.
- [ ] Không thể farm tim bằng cách chỉnh lùi giờ máy (tận dụng `ClampedClock`).
