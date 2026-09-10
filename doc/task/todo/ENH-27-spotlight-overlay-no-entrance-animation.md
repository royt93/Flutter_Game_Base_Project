---
id: ENH-27
title: "SpotlightOverlay (+ TutorialSequence) không có animation vào — scrim/callout xuất hiện tức thì, khác mọi overlay khác trong kit"
type: enhance
priority: P2
effort: S-M
source: Claude, audit UI/animation polish round 6 (parallel fork B)
---

## Vị trí
`lib/presentation/widgets/common/spotlight_overlay.dart` —
`_SpotlightOverlayState.build()` và `_Callout`.

## Hiện trạng
`SpotlightOverlay` chỉ có 1 `setState()` (trong `initState()`'s
`addPostFrameCallback`) để lấy đúng vị trí target sau layout — không có bất
kỳ `AnimationController`/`TweenAnimationBuilder`/implicit-animation nào.
Scrim dim + hole cắt ra + `_Callout` panel xuất hiện TỨC THÌ ngay khi build
đầu tiên chạy xong.

Mọi overlay/dialog khác trong kit đều animate lúc vào:
- `NeonDialog.show`: fade + scale (`ScaleTransition` + `_kDialogCurve`).
- `NeonDialog.overlay`/`.overlaySlot`: `TweenAnimationBuilder`/
  `AnimatedSwitcher` fade+scale.
- `ToastBanner.show`: slide + fade (`easeOutBack`).
- `RewardPopup`: `TweenAnimationBuilder` scale+fade entrance.
- `ConfettiOverlay`/`FloatingComboText`: có animation chuyển động riêng.

`SpotlightOverlay` — widget onboarding/tutorial, ấn tượng đầu tiên người
chơi thấy khi mở app lần đầu — là NGOẠI LỆ DUY NHẤT xuất hiện snap không
animation, thông qua cả `TutorialSequence` (compose `SpotlightOverlay` nên
kế thừa luôn hạn chế này).

## Vì sao cần
Đúng trọng tâm "UI xịn sò + animation xịn sò hơn" — đây là chỗ thiếu rõ
ràng nhất, ảnh hưởng trực tiếp ấn tượng onboarding đầu tiên, và không nhất
quán với toàn bộ overlay còn lại trong kit.

## Đề xuất
Thêm entrance animation nhẹ khi `_targetRect` lần đầu có giá trị (rect !=
null): dim scrim fade in (`AnimatedOpacity` hoặc `TweenAnimationBuilder`
trên `dimColor`'s alpha), `_Callout` scale+fade in tương tự `RewardPopup`
(`TweenAnimationBuilder<double>` 0→1, `Curves.easeOutBack`, ~250ms). Phải
tôn trọng `NeonTheme.reducedMotion(context)` (đã có tiền lệ ENH-17/ENH-20)
— animation collapse còn UI vẫn hiện đúng ngay lập tức.

## Acceptance criteria
- [ ] Scrim + `_Callout` có entrance animation (không còn xuất hiện tức thì) khi `SpotlightOverlay` mount.
- [ ] `NeonTheme.reducedMotion(context)` bật → animation collapse về `Duration.zero`, UI vẫn hiện đúng.
- [ ] `TutorialSequence`'s demo (đã có, compose `SpotlightOverlay`) hưởng animation này mà không cần sửa gì thêm ở `tutorial_sequence.dart`.
- [ ] Test mới xác nhận animation chạy đúng + reducedMotion collapse đúng.
