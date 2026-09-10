---
id: ENH-31
title: "StreakCounter không animate khi days tăng — snap tức thì, khác CurrencyCounter cùng layout"
type: enhance
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork C)
---

## Vị trí
`lib/presentation/widgets/common/streak_counter.dart` — toàn bộ là
`StatelessWidget`, `Text('$days', ...)` render trực tiếp, không animation
nào. Doc comment đầu file tự nhận: "Same layout/spacing as `CurrencyCounter`
but simpler — no count-up animation needed."

## Hiện trạng
`CurrencyCounter` (cùng layout/spacing, cùng nhóm Progress & Reward) đếm số
mượt bằng `TweenAnimationBuilder<int>` (500ms, `easeOut`) mỗi khi `value`
đổi. `StreakCounter` khi `days` tăng (vd sau khi claim daily login) chỉ
snap tức thì sang số mới — không tween, không pop, không glow trên icon lửa
(trong khi `StarRating` glow icon sao, `ProgressBarStars` glow thanh fill).

## Vì sao cần
"Đạt streak mới" là 1 khoảnh khắc thưởng (reward moment) y hệt tinh thần
`RewardPopup`/`StarRating` — hiện tại nó là widget "phẳng" nhất trong cả
nhóm Progress & Reward, không có bất kỳ phản hồi chuyển động nào khi số
tăng, dù widget hàng xóm cùng vai trò (đếm số) đã làm rất tốt.

## Đề xuất
Không cần đổi hẳn thành `StatefulWidget` phức tạp — cách rẻ nhất: bọc
`Icon`/`Text` trong `TweenAnimationBuilder<double>` chạy 1 lần khi `days`
đổi (dùng `ValueKey(days)` + `AnimatedSwitcher` hoặc so sánh
`oldWidget.days` như `CurrencyCounter` đã làm) để tạo hiệu ứng scale-pop
(`Curves.easeOutBack`, 1.0 → 1.2 → 1.0) trên cả icon lửa và số, tôn trọng
`NeonTheme.reducedMotion`.

## Acceptance criteria
- [ ] `StreakCounter` pop/scale nhẹ khi `days` tăng so với giá trị trước đó.
- [ ] `reducedMotion` bật → không animation, số vẫn cập nhật đúng.
- [ ] Test xác nhận animation chạy khi `days` đổi, không chạy khi không đổi.
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Effort thấp nhưng cần quyết định: giữ `StatelessWidget` (dùng
`TweenAnimationBuilder` theo dõi thay đổi qua key) hay chuyển hẳn
`StatefulWidget` như `CurrencyCounter` — cả hai đều hợp lý, nên hỏi ý kiến
trước khi chọn hướng cụ thể.
