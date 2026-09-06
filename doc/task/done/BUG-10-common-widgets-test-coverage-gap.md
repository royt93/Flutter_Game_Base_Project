---
id: BUG-10
title: 20/21 widget trong common/ không có test riêng
type: bug
priority: P1
effort: L
verified: true
source: Claude (cả 3 nguồn agy/claude-CLI/fork đều nêu, đã đếm lại chính xác)
---

## Vị trí
`test/widget/common/` — hiện chỉ có `reward_popup_smoke_test.dart`.
20 widget còn lại trong `lib/presentation/widgets/common/` không có test:
`CommonButton`, `ToggleSwitch`, `SegmentedTabBar`, `IconBadgeButton`,
`LoadingOverlay`, `ToastBanner`, `TooltipBubble`, `BottomSheetPanel`,
`ConfirmDialog`, `ProgressBarStars`, `CircularProgressRing`, `StarRating`,
`CurrencyCounter`, `BadgeDot`, `StreakCounter`, `PanelCard`, `ListTileRow`,
`SectionHeader`, `EmptyStatePlaceholder`, `AvatarFrame`.

## Vì sao quan trọng
Đây là bộ widget "bán" chính của package (README liệt kê đầy đủ 21 widget).
Rủi ro cao nhất nằm ở logic có state/animation (`CommonButton` assert biến
thể, `ToastBanner.show` queue, `CurrencyCounter`/`StarRating` animation
lifecycle, `ConfirmDialog` — xem BUG-01) — hiện không được test tự động, mọi
regression chỉ phát hiện bằng tay qua `WidgetShowcaseScreen`.

## Đề xuất
Ưu tiên viết test theo độ rủi ro giảm dần: `ConfirmDialog` (đã có bug cụ thể),
`CommonButton`, `ToastBanner`, `CurrencyCounter`, `StarRating`, rồi phần còn
lại (chủ yếu layout/card ít logic hơn).

## Acceptance criteria
- [ ] Mỗi widget trong `common/` có ít nhất 1 test file trong `test/widget/common/`.
- [ ] `flutter test --exclude-tags slow` vẫn xanh.
