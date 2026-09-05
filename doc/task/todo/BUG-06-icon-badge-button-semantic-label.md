---
id: BUG-06
title: IconBadgeButton dùng icon.toString() làm Semantics label
type: bug
priority: P2
effort: S
verified: true
source: Claude tự phát hiện khi verify (không phải AI ngoài), đọc code thật
---

## Vị trí
`lib/presentation/widgets/common/icon_badge_button.dart:46-49`

## Vấn đề
`Semantics(button: true, enabled: enabled, label: icon.toString(), ...)` —
không có param `semanticLabel` nào trong constructor để caller truyền nhãn có
nghĩa. Screen reader (TalkBack/VoiceOver) sẽ đọc ra chuỗi debug kiểu
`"IconData(U+0F1C3)"` thay vì "Settings"/"Cài đặt".

## Đề xuất fix
Thêm param `String? semanticLabel` vào `IconBadgeButton`, dùng
`semanticLabel ?? icon.toString()` (giữ fallback cũ để không breaking), theo
đúng pattern đã có ở `CommonButton.semanticLabel`.

## Acceptance criteria
- [ ] `IconBadgeButton` nhận `semanticLabel` tuỳ chọn.
- [ ] `example/lib/screens/widget_showcase_screen.dart` truyền label có nghĩa cho các demo instance.
