---
id: IDEA-16
title: "IconBadgeButton's badge dot/count xuất hiện và đổi số tức thời, không có animation pop-in"
type: idea
priority: P3
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork A)
---

## Vị trí
`lib/presentation/widgets/common/icon_badge_button.dart` — `IconBadgeButton`
là `StatelessWidget` thuần, badge (`_buildDotBadge()`/`_buildCountBadge()`)
là 1 `Container`/`Text` tĩnh, hoàn toàn không có animation nào.

## Hiện trạng
Khi `showBadge`/`badgeCount` đổi giá trị (ví dụ: có thông báo mới, số đếm
tăng), badge xuất hiện hoặc đổi số ngay lập tức trong 1 frame — không có
hiệu ứng "pop" báo hiệu có gì đó vừa thay đổi. So với các widget reward
khác trong kit (`RewardPopup`, `ConfettiOverlay`, `FloatingComboText`) đều
có juice khi 1 sự kiện đáng chú ý xảy ra, badge — vốn CHÍNH LÀ tín hiệu
"có gì đó mới" — lại là nơi im lặng nhất.

## Vì sao cần
Badge notification là 1 trong những UI pattern mà 1 hiệu ứng pop-in nhỏ
(scale từ 0 lên 1, có thể kèm overshoot) mang lại giá trị chú ý cao — đây
chính là công dụng của badge (thu hút mắt nhìn). Hiện tại nó dễ bị bỏ qua
vì không có chuyển động nào báo hiệu.

## Đề xuất
Bọc badge trong `AnimatedSwitcher` hoặc `TweenAnimationBuilder` (đọc
`ConfettiOverlay`/`FloatingComboText` để theo đúng convention `reducedMotion`
đã dùng trong kit) — khi badge chuyển từ ẩn→hiện, hoặc số đếm đổi (dùng
`ValueKey(badgeCount)` để `AnimatedSwitcher` nhận biết đó là nội dung mới),
chạy 1 scale-in ngắn (~150-200ms, có thể overshoot nhẹ). Vẫn phải tôn trọng
`NeonTheme.reducedMotion` như mọi widget khác trong kit đã làm từ ENH-17.

## Acceptance criteria
- [x] Badge có animation pop-in khi chuyển từ ẩn sang hiện, và khi số đếm đổi.
- [x] Tôn trọng `NeonTheme.reducedMotion` (bỏ qua animation, hiện tức thời).
- [x] Test TDD xác nhận animation chạy đúng và reducedMotion tắt animation nhưng badge vẫn hiển thị đúng nội dung.
- [x] Demo trong `WidgetShowcaseScreen` cập nhật để minh hoạ badge đổi số (hiện tại có thể chỉ demo tĩnh).
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — giá trị rõ ràng (badge là tín hiệu chú ý, nên có juice), nhưng
là bổ sung tính năng mới (biến `StatelessWidget` thành có animation) chứ
không phải sửa lỗi, effort có thể lớn hơn ước tính S nếu muốn animation
mượt mà đúng nghĩa thay vì chỉ 1 `TweenAnimationBuilder` đơn giản.

## Quyết định
Chuyển `IconBadgeButton` từ `StatelessWidget` sang `StatefulWidget` với
`SingleTickerProviderStateMixin`, theo đúng convention đã lập ở
ENH-31 (`StreakCounter`)/ENH-32 (`ProgressBarStars`): `AnimationController`
khởi tạo trong `initState` với `value: 1.0` (settled ngay, không pop lúc
mount dù badge hiện sẵn), chỉ `forward(from: 0.0)` trong `didUpdateWidget`
khi badge vừa xuất hiện (`!old._badgeVisible && widget._badgeVisible`) hoặc
khi `badgeCount` đổi số, dùng `Curves.easeOutBack` (bounce nhẹ), tôn trọng
`NeonTheme.reducedMotion`.

Lưu ý kỹ thuật: khởi tạo `AnimationController` trong `initState()` (không
dùng `late final` lazy-init) — nếu để lazy, trường hợp badge không hiện lúc
mount thì `build()` không bao giờ đọc field, khiến nó chỉ được khởi tạo lần
đầu ngay trong `dispose()` (khi widget đã deactivate) → lỗi. Phát hiện qua
1 test failure thật (`semanticLabel` test không có badge hiển thị).

Test dùng lại pattern `StatefulBuilder` + `late StateSetter` đã thiết lập
từ ENH-31/32, và đọc scale qua `Transform.scale`'s `key:
Key('iconBadgeButtonBadgeScale')` (không dùng `find.ancestor` +
`getMaxScaleOnAxis()` vì `PressableScale` cũng bọc 1 `Transform` khác trong
cây, gây match nhầm 2 phần tử).

Demo `WidgetShowcaseScreen`: nút Mail giờ tap được, tăng `badgeCount` mỗi
lần bấm (`onTap: () => setState(() => _mailBadgeCount++)`), minh hoạ pop
sống thay vì chỉ hiện tĩnh số 12.

Test: 5 test mới (root) — mount không pop, showBadge false→true pop,
badgeCount đổi pop, reducedMotion tắt animation. `flutter analyze` sạch cả
root + `example/`. `flutter test --exclude-tags slow`: root 472 passing
(baseline 466 + 6 test mới của cả IDEA-16+17), example 29 passing, không
regression.

Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`): build APK debug
mới, cài qua `adb install -r`, mở Widget Kit → Buttons & Interactive → tap
nút Mail nhiều lần liên tiếp (12→13→...→16), badge cập nhật đúng số mỗi
lần, không exception trong logcat (`mobile_get_device_logs` lọc
`level=Error` rỗng). Không capture được frame giữa pop (giới hạn round-trip
screenshot ~300-800ms > 250ms animation) — bằng chứng chính là test đơn vị
xác nhận đúng curve/controller-transition, device smoke chỉ xác nhận
zero-crash + đúng end-state.
