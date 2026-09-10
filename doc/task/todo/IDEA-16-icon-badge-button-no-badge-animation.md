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
- [ ] Badge có animation pop-in khi chuyển từ ẩn sang hiện, và khi số đếm đổi.
- [ ] Tôn trọng `NeonTheme.reducedMotion` (bỏ qua animation, hiện tức thời).
- [ ] Test TDD xác nhận animation chạy đúng và reducedMotion tắt animation nhưng badge vẫn hiển thị đúng nội dung.
- [ ] Demo trong `WidgetShowcaseScreen` cập nhật để minh hoạ badge đổi số (hiện tại có thể chỉ demo tĩnh).
- [ ] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Ghi chú độ tin cậy
Trung bình — giá trị rõ ràng (badge là tín hiệu chú ý, nên có juice), nhưng
là bổ sung tính năng mới (biến `StatelessWidget` thành có animation) chứ
không phải sửa lỗi, effort có thể lớn hơn ước tính S nếu muốn animation
mượt mà đúng nghĩa thay vì chỉ 1 `TweenAnimationBuilder` đơn giản.
