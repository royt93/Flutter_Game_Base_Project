---
id: IDEA-23
title: "DailyLoginCalendarWidget hoàn toàn tĩnh — bấm Claim không có phản hồi chuyển động nào"
type: idea
priority: P3
effort: M
source: Claude, audit UI/animation polish round 6 (parallel fork C)
---

## Ý tưởng
`DailyLoginCalendarWidget`/`_DaySlot` đều là `StatelessWidget` thuần, không
1 dòng animation nào trong cả file. Khi `onClaim` được gọi (thường dẫn tới
`setState` ở tầng cha khiến `claimedDaysInCycle` đổi), ô ngày hiện tại
chuyển từ viền cyan "current" sang nền vàng gold + icon check ngay lập
tức — snap tức thì, không transition.

## Vì sao cần
Claim daily login là 1 trong những khoảnh khắc "thưởng" quan trọng nhất
của 1 casual game (y hệt tinh thần `RewardPopup`) — nhưng đây lại là widget
tĩnh nhất trong toàn bộ nhóm Progress & Reward, không có bất kỳ pop/scale/
glow-pulse nào khi claim thành công, dù widget hàng xóm cùng chủ đề
"reward" (`StarRating`, `ProgressBarStars`' marker sau ENH-32,
`RewardPopup`) đều có juice khá rõ.

## Đề xuất
Khi 1 `_DaySlot` chuyển từ `current`/chưa `claimed` sang `claimed`, chạy 1
animation ngắn: scale pop (`easeOutBack`, giống `StarRating`) + có thể
thêm 1 nhấp nháy glow ngắn trước khi icon check hiện ra. Cần
`AnimatedSwitcher` hoặc chuyển `_DaySlot` thành `StatefulWidget` theo dõi
`claimed` qua `didUpdateWidget` để phát hiện đúng thời điểm "vừa chuyển
sang claimed" (không animate lại các ô đã claimed từ trước khi mount).

## Acceptance criteria
- [x] Ô ngày pop/scale khi chuyển sang trạng thái `claimed` (không phải khi mount lần đầu đã claimed sẵn).
- [x] `reducedMotion` bật → không animation.
- [x] Test xác nhận animation chạy đúng lúc chuyển trạng thái, không chạy khi mount với trạng thái đã claimed.
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — nhu cầu rõ nhưng cần đổi `_DaySlot` từ Stateless sang
Stateful để theo dõi transition đúng cách, effort không nhỏ như các ENH
khác trong round này. Nên cân nhắc so với ENH-31/ENH-32 (cùng ý tưởng
"thêm pop cho reward moment" nhưng effort thấp hơn) trước khi chọn làm cả
3 hay chỉ 1-2.

## Quyết định
Làm đúng đề xuất, KHÔNG thêm glow-pulse phụ (chỉ scale pop, giống
`StarRating`) — giữ effort tối thiểu, đủ dùng, tránh thêm animation lớp
thứ 2 không cần thiết. `_DaySlot` chuyển từ `StatelessWidget` sang
`StatefulWidget` (`SingleTickerProviderStateMixin`), theo đúng convention
đã lập ở ENH-31 (`StreakCounter`)/IDEA-16 (`IconBadgeButton`):
`AnimationController` bắt đầu `value: 1.0` (settled ngay, không pop lúc
mount dù ô đã claimed sẵn), chỉ `forward(from: 0.0)` trong
`didUpdateWidget` khi `!old.claimed && widget.claimed`, `Curves.easeOutBack`
(0.6→1.0), tôn trọng `NeonTheme.reducedMotion`.

Test dùng `Key('daySlotScale')` giống nhau trên mọi `_DaySlot` (hợp lệ vì
mỗi instance nằm dưới 1 parent khác nhau, không phải sibling cần key khác
nhau để reconcile) — test đọc qua `tester.widgetList<Transform>(...)
.elementAt(index)` để chọn đúng ô ngày cần kiểm tra.

Test: 3 test mới (root). `flutter analyze` sạch cả root + `example/`.
`flutter test --exclude-tags slow`: tất cả pass, không regression.

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): mở Widget Kit
→ Progress & Reward → DailyLoginCalendarWidget → bấm "Claim", ô ngày 1
chuyển đúng sang gold + checkmark, nút Claim disable đúng sau khi claim,
không exception trong logcat. Không capture được frame giữa pop (300ms <
round-trip latency, giới hạn đã ghi nhận nhiều lần trong session) — bằng
chứng chính là test đơn vị xác nhận đúng scale range + điều kiện
transition, device smoke xác nhận end-state đúng + zero-crash.
