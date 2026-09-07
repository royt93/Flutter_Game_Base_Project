---
id: ENH-20
title: "SegmentedTabBar's AnimatedAlign không check NeonTheme.reducedMotion — sót từ ENH-17"
type: enhance
priority: P2
effort: S
source: Claude, audit round 4 (fork agent)
---

## Vị trí
`lib/presentation/widgets/common/segmented_tab_bar.dart:39-40`:
```dart
AnimatedAlign(
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOut,
  ...
```

## Hiện trạng
ENH-17 (đã đóng, `doc/task/done/ENH-17-widgets-missing-reduced-motion-check.md`)
audit + sửa 13 widget dùng `TweenAnimationBuilder`/`AnimationController`/
`Ticker` để tôn trọng `NeonTheme.reducedMotion(context)`, nhưng danh sách đó
không có `segmented_tab_bar.dart`. Grep lại toàn bộ `lib/presentation/` cho
`AnimatedContainer|AnimatedAlign|AnimatedOpacity|AnimatedSize|AnimatedSwitcher|
TweenAnimationBuilder|AnimationController|createTicker` cho thấy đây là widget
DUY NHẤT còn sót — mọi widget khác trong danh sách đó (kể cả
`currency_counter`, `star_rating`, `squash_stretch`, `screen_shake`,
`combo_heat_background` — không nằm trong 13 file ENH-17 sửa vì đã đúng từ
trước) đều đã có check. `SegmentedTabBar` là `StatelessWidget` với `context`
sẵn có ngay trong `build()` — không cần né `initState()` như một số case
ENH-17 từng gặp.

## Vì sao cần
Cùng lý do ENH-17: `reducedMotion` là accessibility helper trung tâm của
package, thiếu ở 1 widget là thiếu nhất quán. `AnimatedAlign` ở đây là sliding
pill trang trí thuần (không mang thông tin trạng thái ngoài vị trí, giống hệt
`CandyToggleSwitch`'s `AnimatedContainer`/`AnimatedAlign` mà ENH-17 đã sửa).

## Đề xuất fix
```dart
AnimatedAlign(
  duration: NeonTheme.reducedMotion(context)
      ? Duration.zero
      : const Duration(milliseconds: 220),
  curve: Curves.easeOut,
  ...
```
Thêm 1 test trong `test/widget/common/segmented_tab_bar_test.dart` theo đúng
pattern các test `ENH-17: Reduce Motion bật → ... duration = 0` đã có ở
`toggle_switch_test.dart`/`paginated_dots_indicator_test.dart`.

## Acceptance criteria
- [x] `AnimatedAlign`'s `duration` → `Duration.zero` khi `reducedMotion` bật.
- [x] Test mới xác nhận hành vi dưới `reducedMotion`, cùng pattern các test ENH-17 khác.
- [x] `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root và `example/`.

## Quyết định
Sửa đúng như đề xuất, TDD: viết test trước (đọc `AnimatedAlign` widget,
assert `duration == Duration.zero` khi `MediaQueryData(disableAnimations:
true)`), xác nhận fail đúng lý do trước khi sửa. Verify: `flutter analyze`
sạch + `flutter test --exclude-tags slow` 429 pass ở root (428 + 1 mới), 29
pass ở `example/`. Device smoke trên Pixel 7 Pro thật (`2B051FDH3006MU`,
S24U không cắm được lúc này) — mở Widget Kit, bấm đổi tab Easy→Hard, pill
trượt mượt, không exception/overflow trong live log.
