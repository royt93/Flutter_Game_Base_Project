---
id: FEAT-17
title: Tôn trọng cờ Reduce Motion (MediaQuery.disableAnimations)
type: feature
priority: P1
effort: M
verified: true
source: Claude, verify lại code thật (grep toàn repo không thấy check nào)
---

## Vấn đề
Kit dùng animation/shader dày đặc (`AuroraBgLayer`, `NeonAuraLayer`,
`PressableScale`, `CurrencyCounter`, `StarRating`...) nhưng grep toàn bộ
`lib/`/`example/lib/` xác nhận: không nơi nào đọc
`MediaQuery.of(context).disableAnimations` — cờ hệ điều hành cho người dùng
nhạy cảm với chuyển động (say tàu xe, rối loạn tiền đình...).

## Đề xuất fix
Thêm 1 helper trung tâm (ví dụ `NeonTheme.reducedMotion(context)`) mà các
widget animation-heavy tự check trước khi chạy hiệu ứng (tắt hẳn shader
background, rút ngắn/bỏ animation curve về instant nếu cờ bật) — làm ở 1 lớp
chung, không sửa từng widget riêng lẻ.

## Acceptance criteria
- [ ] Bật "Reduce Motion" ở OS (giả lập qua `MediaQuery` override trong test) → `AuroraBgLayer`/`NeonAuraLayer` không chạy ticker, animation widget chuyển trạng thái tức thời.
