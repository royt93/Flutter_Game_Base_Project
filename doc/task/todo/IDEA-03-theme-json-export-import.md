---
id: IDEA-03
title: "Theme/skin export-import JSON — '1 file = 1 theme'"
type: idea
priority: exclusive
effort: M
source: agy
---

## Ý tưởng
`NeonTheme` đã tách token màu khỏi widget rất sạch (đổi `NeonTheme.dark`
không cần sửa call site nào). Đóng gói khả năng export/import toàn bộ palette
thành 1 file JSON — cho phép studio nhỏ "reskin" game chỉ bằng đổi 1 file, phù
hợp mô hình nhiều game dùng chung core khác da (game-farm).

## Vì sao khác biệt
Kit khác thường hardcode token trong Dart, đổi theme phải sửa code + build
lại. Kit này có sẵn kiến trúc token tách rời, chỉ thiếu lớp serialize/
deserialize JSON để biến nó thành tính năng thực sự dùng được không cần code.
