---
id: IDEA-91
title: "Gate CHANGELOG cho thay đổi hành vi không nằm trong chữ ký API"
type: idea
layer: tool/api_compatibility
priority: P3
effort: M
source: "ENH-103 đổi getter lockedBorder/lockedFill và key palette; api_snapshot không thấy là breaking dù consumer có thể bị ảnh hưởng"
---

## Ý tưởng
`api_compatibility` so chữ ký công khai; thay đổi như đổi key `exportPalette`, đổi giá trị mặc định token, đổi mutable field thành getter chỉ qua test nội bộ. Mở rộng gate: snapshot thêm **`NeonTheme.exportPalette()` keys** và **giá trị mặc định token công khai**; khác biệt buộc CHANGELOG có mục `Behavior change`.

## Giá trị
Đảm bảo CHANGELOG ghi trung thực những thay đổi consumer thấy được.

## Cân nhắc
Chỉ có giá trị khi đã có consumer thật; cũng cần quy ước chữ "Behavior change" thống nhất với "BREAKING" hiện có.
