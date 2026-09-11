---
id: ENH-34
title: "VictoryCardTemplate/GameOverCardTemplate render tức thì, không có entrance animation như RewardPopup"
type: enhance
priority: P2
effort: S
source: Claude, audit UI/animation polish round 6 (parallel fork D)
---

## Vị trí
- `lib/presentation/widgets/common/victory_card_template.dart` — `build()`, trả thẳng `PanelCard(...)`.
- `lib/presentation/widgets/common/game_over_card_template.dart` — tương tự, trả thẳng `PanelCard(...)`.

## Hiện trạng
Cả 2 đều là `StatelessWidget` thuần, không `TweenAnimationBuilder`/
`AnimationController` nào — xuất hiện tức thì khi mount, không scale/fade
in. Trong khi đó `RewardPopup` (cùng nhóm "khoảnh khắc kết quả lớn") có
`TweenAnimationBuilder<double>` với `Curves.easeOutBack`, scale
`0.85 + 0.15*t` + fade — một hiệu ứng "pop in" rõ ràng, cảm giác cao cấp
hơn hẳn. VictoryCardTemplate/GameOverCardTemplate là 2 màn hình "kết quả"
tương đương về mặt cảm xúc (thắng/thua) nhưng thiếu chính xác hiệu ứng đó.

## Vì sao cần
Đây là 2 trong số những khoảnh khắc có tác động cảm xúc lớn nhất của 1
casual game (level complete / game over) — thiếu entrance animation trong
khi widget "anh em" (RewardPopup) đã có là 1 điểm không nhất quán rõ, và là
cơ hội "premium feel" dễ thấy nhất trong kit.

## Đề xuất
Bọc nội dung `PanelCard` của cả 2 widget trong cùng 1
`TweenAnimationBuilder<double>` pattern RewardPopup đã dùng (scale +
fade, `Curves.easeOutBack`, ~320ms), tôn trọng `NeonTheme.reducedMotion`
(duration → `Duration.zero` khi bật, đúng pattern đã áp dụng toàn kit).

## Acceptance criteria
- [x] Cả 2 widget có entrance scale+fade khớp `RewardPopup`'s hiệu ứng.
- [x] `NeonTheme.reducedMotion` → animation collapse, không throw.
- [x] Test xác nhận animation chạy + reducedMotion path.

## Quyết định
Bọc y hệt `RewardPopup`'s pattern: `TweenAnimationBuilder<double>(tween:
Tween(0,1), curve: easeOutBack, 320ms)` → `Opacity(t.clamp(0,1))` +
`Transform.scale(0.85+0.15*t)`, bọc quanh `PanelCard(...)` return sẵn có
của cả 2 widget (chỉ thêm layer bọc ngoài, không đổi nội dung bên trong).
Test: assert `TweenAnimationBuilder<double>`'s `duration`/`curve` đúng giá
trị, và `duration = Duration.zero` khi `reducedMotion` bật. Verify:
`flutter analyze` sạch + `flutter test` 457 pass ở root (453+4 mới), 29
pass ở `example/` (bao gồm test `VictoryCardTemplate` dùng
`RepaintBoundary`+`share_helper` — vẫn pass, xác nhận layer bọc mới không
phá luồng share). Device smoke Pixel 7 Pro thật: cả 2 template render
đúng, settled state (opacity=1, scale=1) không méo, không exception —
không chụp được khoảnh khắc entrance vì widget mount ngay lúc load
màn hình (trước khi cuộn tới), animation đã xong từ trước.
