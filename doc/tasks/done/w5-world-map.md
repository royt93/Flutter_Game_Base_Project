---
id: w5-world-map
title: World Map node-based
wave: 5
group: Hành trình
status: todo
owner: claude
---

## Mục tiêu
Màn bản đồ hành trình kiểu Candy Crush: đường đi uốn lượn, node từng màn, cờ thế giới, sao trên đường.

## Phạm vi
- `WorldMapScreen`: CustomScrollView dọc, CustomPainter vẽ đường path nối các node (zig-zag), node = màn (số + sao + trạng thái khoá/hiện tại/đã xong).
- Banner phân khu thế giới xen giữa path.
- Node hiện tại pulse + nút "CHƠI"; tap node mở khoá → start level.
- Toggle giữa Map view và Grid view (giữ Level Select cũ làm tuỳ chọn) — hoặc thay thế.
- i18n (giữ key cũ).

## Acceptance
- Cuộn mượt 100 node; tap đúng màn; khoá đúng tiến trình. 0 analyzer issue, build OK.
</content>
