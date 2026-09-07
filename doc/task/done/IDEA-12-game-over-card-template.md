---
id: IDEA-12
title: "GameOverCardTemplate — panel mẫu cho màn hình thua/hết lượt, đối xứng với VictoryCardTemplate"
type: idea
priority: P3
effort: S-M
source: Claude, đề xuất feature mới (round 5)
---

## Ý tưởng
`VictoryCardTemplate` (`lib/presentation/widgets/common/victory_card_template.dart`)
đã có panel mẫu cho khoảnh khắc "thắng" (title + stat lines + avatar + QR +
share). Không có panel tương ứng cho khoảnh khắc "thua/hết lượt/hết energy"
— một casual game luôn cần cả hai màn hình này, và chúng khác nhau đủ nhiều
(không có QR/share, có nút Retry/Home, tông màu khác) để không tiện chỉ
truyền `accentColor` khác vào `VictoryCardTemplate`.

## Vì sao cần
Đây là 1 trong 2 khoảnh khắc phổ biến nhất của mọi casual game (thắng/thua),
nhưng kit hiện chỉ có template cho 1 nửa. Consumer app hiện phải tự dựng từ
đầu bằng `PanelCard` + `CommonButton` — làm được nhưng không có "living
reference" như `VictoryCardTemplate` đang có cho phía thắng.

## Đề xuất
`GameOverCardTemplate`: `title` (String, vd "Out of moves!"), `message`
(String?), `icon`/`accentColor` (mặc định buồn hơn — `NeonTheme.muted` hay
tương tự thay vì `gold`), `statLines` (List<String>, cùng convention
caller-supplied như `VictoryCardTemplate`), `primaryAction`
(label + callback, vd "Retry"), `secondaryAction` (label + callback, vd
"Home", optional). Không cần QR/share — nếu sau này cần, thêm sau, không
làm ngay để giữ tối giản.

## Acceptance criteria
- [ ] Widget mới `lib/presentation/widgets/common/game_over_card_template.dart`, export qua `common_widgets.dart`.
- [ ] Test TDD: render title/message/statLines, primaryAction/secondaryAction gọi đúng callback, secondaryAction null thì không render nút thứ 2.
- [x] Demo trong `WidgetShowcaseScreen`.
- [x] `flutter analyze`/`flutter test` sạch ở root + `example/`, device smoke test.

## Quyết định
Widget riêng (`GameOverCardTemplate`), không chung class với
`VictoryCardTemplate` — 2 template khác nhau đủ nhiều (không QR/share,
2 nút action thay vì 1) nên tách class rõ ràng hơn 1 flag `isWin` rẽ nhánh
nhiều nhánh nội bộ. TDD: viết test trước, xác nhận fail đúng lý do. Ghi chú
khi viết test: `StrokeText`/`CommonButton` render 2 `Text` (stroke+fill),
nên dùng `findsWidgets`/`.first` khi assert text/tap, giống pattern
`victory_card_template_test.dart` đã dùng. Verify: `flutter analyze` sạch +
`flutter test` 434 pass ở root (429+5 mới), 29 pass ở `example/`. Device
smoke trên Pixel 7 Pro thật — card render đúng tông muted, icon buồn, tap
Retry hiện toast "Retry tapped", không exception/overflow.

## Ghi chú độ tin cậy
Trung bình-cao — nhu cầu rõ ràng, đối xứng trực tiếp với 1 widget đã có sẵn
và được dùng làm ví dụ tham chiếu. Rủi ro duy nhất là tên gọi/API cụ thể
(vd có nên chung 1 class với `VictoryCardTemplate` qua 1 `isWin` flag thay
vì 2 class riêng?) — cần xác nhận hướng trước khi làm.
