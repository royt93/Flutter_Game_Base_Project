---
id: IDEA-13
title: "WheelSpinner — widget bánh xe may mắn (spin-to-win), cơ chế casual kinh điển chưa có trong kit"
type: idea
priority: P3
effort: M
source: Claude, đề xuất feature mới (round 5)
---

## Ý tưởng
Vòng quay phần thưởng ("spin the wheel") là 1 trong những cơ chế reward phổ
biến nhất của casual game (daily spin, ad-reward spin...) — kit hiện có
`RewardPopup`/`DailyLoginCalendarWidget`/`EnergyBar` cho các dạng reward
khác nhưng chưa có widget vòng quay nào trong 40 widget hiện tại (đã kiểm
tra `common_widgets.dart` và toàn bộ `lib/presentation/widgets/`).

## Vì sao cần
Cơ chế độc lập hoàn toàn với các widget reward đã có (không widget nào
overlap), giá trị demo rất trực quan trong `WidgetShowcaseScreen`.

## Đề xuất
`WheelSpinner`: nhận `segments` (List<WheelSegment> — mỗi segment có
label/color/value, caller-supplied, giống convention `LeaderboardEntry`),
`onSpinEnd(WheelSegment result)` callback. Widget tự vẽ bánh xe bằng
`CustomPainter` (không phụ thuộc thêm package ngoài), animate xoay tới góc
tương ứng kết quả bằng `AnimationController` (tôn trọng `NeonTheme.
reducedMotion` — animation collapse nhưng vẫn phải gọi `onSpinEnd` đúng,
theo đúng pattern đã dùng ở `ConfettiOverlay`/`CoinFlyOverlay`). Kết quả
(segment nào thắng) do RNG **của caller** quyết định trước (truyền vào qua
tham số `resultIndex`, không phải widget tự random) — giữ đúng nguyên tắc
"widget không tự nghĩ ra logic random/ranking" đã áp dụng nhất quán ở
`VictoryCardTemplate`/`LeaderboardList`.

## Acceptance criteria
- [ ] Widget mới `lib/presentation/widgets/common/wheel_spinner.dart` + `WheelSegment` data class, export qua `common_widgets.dart`.
- [ ] Test TDD: render đủ segment, gọi `spin(resultIndex)` rồi settle animation → `onSpinEnd` nhận đúng segment, reducedMotion → animation collapse nhưng callback vẫn fire.
- [ ] Demo trong `WidgetShowcaseScreen`.
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test (animation quay + haptic khi dừng, nếu có).

## Ghi chú độ tin cậy
Trung bình — hữu ích rõ ràng nhưng effort lớn hơn hẳn các widget khác trong
kit (CustomPainter vẽ bánh xe nhiều segment + easing animation dừng đúng
góc là phần khó nhất, cần cẩn thận về toán học góc quay). Nên cân nhắc kỹ
effort trước khi chọn nếu muốn 1 round gọn.
