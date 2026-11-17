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

## Đã làm (2026-11-17)
- `tool/api_compatibility.dart`: snapshot thêm `tokens` (đọc `NeonTheme._defaultPalette`, key và `#RRGGBB`, cùng không gian key với `exportPalette()`). `check` so sánh; token đổi giá trị hoặc thêm/bớt key thì CHANGELOG (mục `## Unreleased`, nếu không có thì mục version hiện tại) phải có dòng **Behavior change** nhắc tên key (khớp cả dạng bỏ hậu tố Light/Dark, ví dụ `inkSoft` khớp `inkSoftLight`). Snapshot cũ không có `tokens` thì bỏ qua, không lỗi.
- Test: 5 ca trong `test/tool/api_compatibility_check_test.dart` (ghi tokens, đổi mà không có Behavior change thì đỏ, có nhắc đúng token thì xanh và in `Token changes`, có Behavior change nhưng không nhắc token thì đỏ, snapshot cũ bỏ qua). Thử tay trên repo thật: đổi `cyan` đỏ, thêm dòng Behavior change thì xanh.
- Chưa theo dõi: getter/hằng không nằm trong `_defaultPalette` (spacing, kích thước, giá trị mặc định tham số widget).
