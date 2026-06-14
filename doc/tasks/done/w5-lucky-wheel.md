---
id: w5-lucky-wheel
title: Lucky Wheel / Vòng quay may mắn
wave: 5
group: Meta giữ chân
status: todo
owner: claude
---

## Mục tiêu
Vòng quay miễn phí 1 lần/ngày nhận xu hoặc booster (bổ sung cho daily streak).

## Phạm vi
- 8 ô phần thưởng (xu nhỏ/vừa/lớn + booster). Logic chọn ô (xoay theo index, không random `Math.random` cấm — dùng nguồn quay từ clock/streak).
- `LuckyWheelController` (GetX) + StorageKeys.wheelLastSpin (epoch-day).
- Overlay trên Home (NeonDialog.overlay): bánh xe vẽ bằng CustomPainter, animation xoay, dừng ở ô trúng, trao thưởng.
- Nút Home + badge khi có lượt quay.
- i18n.

## Acceptance
- Quay 1 lần/ngày; trao thưởng đúng ô; test logic ô trúng + reset theo ngày.
- 0 analyzer issue.
</content>
