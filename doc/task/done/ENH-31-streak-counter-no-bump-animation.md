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
- [x] `StreakCounter` pop/scale nhẹ khi `days` tăng so với giá trị trước đó.
- [x] `reducedMotion` bật → không animation, số vẫn cập nhật đúng.
- [x] Test xác nhận animation chạy khi `days` đổi, không chạy khi không đổi.
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Quyết định
Chuyển hẳn sang `StatefulWidget` với `AnimationController` tường minh
(value mặc định 1.0, chỉ `forward(from: 0.0)` khi `didUpdateWidget` phát
hiện `days` tăng) — KHÔNG dùng kỹ thuật "ép" `TweenAnimationBuilder` replay
qua đổi `key` như thử ban đầu: kỹ thuật đó tạo ra 1 bug thật rất khó phát
hiện (query widget ngay sau khi đổi key trả về giá trị SAI — builder thật
sự chạy đúng scale nhưng `tester.widget<Transform>()` đọc lại cho kết quả
khác, nguyên nhân chính xác không xác định được dù đã debug sâu bằng
debugPrint nhiều lớp; nghi do thứ tự deactivate/finalize element khi đổi
key). Cách `AnimationController` tường minh ổn định, dễ verify, và là
đúng pattern `CurrencyCounter` gợi ý. Phát hiện phụ trong lúc debug:
`Matrix4.getMaxScaleOnAxis()` trả sai giá trị cho ma trận scale thuần
trong bản Flutter/vector_math hiện tại (verify bằng cách in `storage`
thô — đúng 0.7 — trong khi `getMaxScaleOnAxis()` báo 1.0) — test đọc trực
tiếp `transform.storage[0]` thay vì gọi hàm đó. Verify: `flutter analyze`
sạch + `flutter test` 466 pass ở root (461+... gộp ENH-31+32), 29 pass ở
`example/`. Device smoke Pixel 7 Pro thật: không crash/exception, xác
nhận CircularProgressRing (glow, ENH-30) cập nhật đúng 40%→60% khi bấm nút
kế bên — không bắt được khoảnh khắc pop 300ms qua screenshot do animation
quá ngắn so với round-trip điều hướng.
