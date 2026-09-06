---
id: IDEA-08
title: "Juice / Game-feel micro-interaction framework"
type: idea
priority: exclusive
effort: L
source: agy
---

## Ý tưởng
Đóng gói sẵn các hiệu ứng "game-feel" tiêu chuẩn cho non-designer dev:
- Squash & Stretch wrapper (spring simulation khi chạm/thả).
- Screen Shake controller (intensity/frequency/decay có thể cấu hình, dùng
  cho combo lớn/nổ bom/thất bại).
- Combo Heat reactive background (đổi màu nền theo streak hiện tại, tận dụng
  hạ tầng shader/ticker đã có).

## Vì sao khác biệt
`PressableScale` đã có sẵn 1 dạng game-feel cơ bản (scale khi nhấn) — mở rộng
thành 1 bộ hiệu ứng đầy đủ hơn giúp game "đã tay" mà dev không cần tự thiết
kế animation curve từ đầu, khác biệt so với kit chỉ cung cấp widget tĩnh.
