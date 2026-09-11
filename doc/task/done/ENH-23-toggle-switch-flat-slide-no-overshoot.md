---
id: ENH-23
title: "CandyToggleSwitch's thumb slide + track color dùng Curves.easeOut phẳng, không có overshoot khi thumb chạm biên"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork A)
---

## Vị trí
`lib/presentation/widgets/common/toggle_switch.dart` — cả `AnimatedContainer`
(track color) và `AnimatedAlign` (thumb position) dùng chung
`curve: Curves.easeOut`, 180ms.

## Hiện trạng
Thumb trượt từ trái sang phải (hoặc ngược lại) và dừng lại đúng vị trí biên
mà không có bất kỳ độ nảy/overshoot nào — chuyển động phẳng, giống easing
mặc định của Material `Switch` hơn là 1 toggle "candy" riêng biệt của kit
này. Track color cũng đổi cùng nhịp phẳng.

## Vì sao cần
1 toggle switch trong 1 kit đã đầu tư nhiều vào "candy juice" ở nơi khác
(`RewardPopup`'s burst, `ConfettiOverlay`, `NeonDialog`'s
`Curves.easeOutBack` entrance) mà lại phẳng ở đây là thiếu nhất quán về
"độ nảy" giữa các widget tương tác — người dùng bấm toggle rất thường
xuyên (settings, filter...) nên cảm giác chạm ở đây đáng được đầu tư ngang
các widget khác.

## Đề xuất
Đổi `curve` của `AnimatedAlign` (thumb) sang `Curves.easeOutBack` hoặc
tương đương để thumb hơi vượt quá vị trí đích rồi mới ổn định — khớp đúng
"ngôn ngữ chuyển động" `NeonDialog`/`RewardPopup` đã dùng. Track color giữ
`easeOut` thuần (màu sắc overshoot sẽ tạo hiệu ứng lạ, không nên áp dụng
cho color tween) — chỉ đổi curve của phần chuyển động vị trí (thumb).

## Acceptance criteria
- [ ] `AnimatedAlign`'s curve đổi sang có overshoot, track color giữ nguyên `easeOut`.
- [ ] Vẫn tôn trọng `NeonTheme.reducedMotion` (đã có sẵn, không đổi).
- [x] Test xác nhận thumb animation dùng đúng curve mới, reducedMotion vẫn duration = 0.
- [x] Device smoke test: bật/tắt toggle vài lần trên máy thật, xác nhận thumb có cảm giác "nảy" nhẹ chứ không máy móc.

## Quyết định
Chỉ đổi `AnimatedAlign` (vị trí thumb) sang `Curves.easeOutBack` + tăng
duration 180ms → 220ms cho bounce đọc được; `AnimatedContainer` (màu track)
giữ nguyên `Curves.easeOut` — đổi màu không có khái niệm overshoot hợp lý.
Cùng pattern ENH-22. Verify: `flutter analyze` sạch + `flutter test` 448
pass ở root (446+2 mới, gộp chung với ENH-24), 29 pass ở `example/`. Device
smoke Pixel 7 Pro thật: bật/tắt toggle nhiều lần, không crash/exception.

## Ghi chú độ tin cậy
Trung bình-cao — nhận định "phẳng, không overshoot" là khách quan (đọc
được từ code), nhưng "nên có overshoot" là lựa chọn thẩm mỹ — nên xem demo
trực tiếp trên thiết bị trước khi merge, dễ chỉnh curve/giá trị sai làm
thumb trông "giật" thay vì "nảy" nếu overshoot quá mạnh.
