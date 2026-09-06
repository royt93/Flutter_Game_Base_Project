---
id: ENH-08
title: WidgetShowcaseScreen tự vi phạm khuyến nghị NeonDialog overlay pattern
type: enhance
priority: P2
effort: S
source: Claude-CLI, verify lại code thật
---

## Vị trí
`example/lib/screens/widget_showcase_screen.dart:87-106`

## Vấn đề
File này dùng `showDialog` gốc của Flutter thay vì `NeonDialog.show`/`.overlay`,
trong khi CLAUDE.md ghi rõ "Prefer the overlay pattern for any dialog from the
start" và chính file này được mô tả là "living reference" cho cách dùng widget
kit — tức mẫu tham khảo đang không theo đúng khuyến nghị của chính dự án.

## Đề xuất fix
Đổi đoạn demo dialog trong `WidgetShowcaseScreen` sang dùng `NeonDialog`/
`ConfirmDialog` cho nhất quán với phần còn lại của màn hình và với khuyến nghị
trong CLAUDE.md.

## Acceptance criteria
- [ ] Không còn lời gọi `showDialog` gốc trong `example/lib/`.
