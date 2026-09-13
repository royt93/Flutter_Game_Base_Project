---
id: IDEA-41
title: "[Exclusive] Adaptive Haptic Choreography cho combo/reward/error"
type: idea
priority: exclusive-medium
effort: M
source: Codex synthesis + prior Claude independent opinion
depends_on: [ENH-36]
---

## Cơ hội
Kit đã có `HapticLevel`, soft mode và `hapticLevelForGroupSize`, nhưng consumer vẫn phải gọi từng rung rời rạc. Một choreography data-driven cho combo/reward có thể tạo game feel nhất quán và tự hạ cường độ theo accessibility/device capability.

## MVP slices
1. Pure model `HapticPattern` gồm các pulse/delay có giới hạn an toàn.
2. Scheduler inject được, cancel/replace khi event mới tới; preset reward/combo/warning.
3. Tôn trọng enabled/soft/reduced-motion và không giữ timer sau dispose.
4. Example playground chỉnh pattern; không phụ thuộc vendor haptic SDK.

## Acceptance criteria
- [ ] Pattern deterministic, cancel được và rate-limit rage tap.
- [ ] Disabled/soft/reduced-motion cho kết quả đúng contract.
- [ ] Không timer/lifecycle leak; preset có tài liệu dùng.
- [ ] Unit, widget, integration và device smoke test chứng minh pulse order/timing trên máy thật.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan. Implement từng slice bằng TDD. Mỗi vòng phải audit code changes, chấm /10, bổ sung unit + widget + integration test mọi case, analyze/test root + example, smoke Android device thật và lưu log/video bằng chứng. Lặp đến >9/10 rồi mới commit + push; sau push cập nhật Quyết định, chuyển done, commit + push lần hai.

