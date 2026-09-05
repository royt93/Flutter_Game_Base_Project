---
id: FEAT-22
title: onTapThrottled/debounce helper chống rage-tap double action
type: feature
priority: P1
effort: S
source: user pick (chốt trong phiên chọn util mới)
---

## Vì sao cần
Bug phổ biến trong game thật: người chơi tap liên tục (rage-tap) gây double
action (mua 2 lần, chuyển màn 2 lần, submit 2 lần). Kit hiện không có cơ chế
chống nào ở tầng chung — mỗi widget/callback phải tự lo (`CommonButton` hiện
không có throttle tích hợp, đã grep xác nhận không có `Debounce`/`Throttle`
nào trong `lib/`).

## Đề xuất phạm vi
1 helper thuần (không phụ thuộc widget cụ thể) trong `lib/core/utils/`:
```dart
VoidCallback throttled(VoidCallback fn, {Duration window = const Duration(milliseconds: 600)});
```
Không tự động áp vào mọi `CommonButton` (tránh thay đổi hành vi ngầm phá vỡ
test/call site hiện có) — để caller tự bọc khi cần, có thể tích hợp làm param
tuỳ chọn cho `CommonButton` ở 1 task riêng sau nếu cần.

## Yêu cầu test
- **Unit test**: gọi callback nhiều lần liên tiếp trong window → chỉ chạy 1 lần; gọi lại sau khi hết window → chạy tiếp lần mới. Dùng `fake_async`/`Timer` kiểm soát thời gian, không phụ thuộc `sleep` thật.
- **Widget test**: bọc 1 `CommonButton.onTap` bằng `throttled(...)`, giả lập nhiều tap liên tiếp nhanh (`tester.tap` nhiều lần trong 1 khung `pump`), assert callback thật chỉ chạy đúng số lần mong đợi.

## Demo
Thêm 1 ví dụ trong `WidgetShowcaseScreen` (nút đếm số lần bấm thật thi hành, so sánh có/không throttle).

## Acceptance criteria
- [ ] Rage-tap 10 lần liên tiếp trong window → callback thật chỉ chạy 1 lần.
- [ ] Không che giấu lỗi logic thật (chỉ chặn double-fire, không nuốt lỗi nếu callback throw).
