---
id: ENH-07
title: Widget kit dùng toạ độ vật lý, chưa hỗ trợ RTL
type: enhance
priority: P2
effort: L
source: Claude-CLI
---

## Hiện trạng
Toàn bộ 21+9 widget dùng `left`/`right`, `Alignment.centerLeft`/... (toạ độ
vật lý) thay vì `AlignmentDirectional`/`PositionedDirectional` (toạ độ theo
hướng đọc). Với app dùng kit này để phát hành ra thị trường dùng chữ Ả Rập/
Hebrew (RTL), layout sẽ hiển thị sai hướng.

## Đề xuất
Không cần làm ngay nếu chưa có nhu cầu RTL cụ thể — ghi nhận làm nợ kỹ thuật
đã biết. Khi cần, rà từng widget đổi sang API directional tương ứng, test lại
bằng `Directionality(textDirection: TextDirection.rtl, ...)`.

## Acceptance criteria
- [ ] (Khi triển khai) mỗi widget hiển thị đúng hướng khi bọc trong `Directionality.rtl`.
