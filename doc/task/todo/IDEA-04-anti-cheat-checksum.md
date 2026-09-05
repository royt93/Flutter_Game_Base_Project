---
id: IDEA-04
title: Anti-cheat checksum (HMAC) cho StorageService export/import
type: idea
priority: exclusive
effort: M
source: agy
---

## Ý tưởng
Thêm mã checksum/HMAC nhẹ khi export/import toàn bộ dữ liệu qua
`StorageService`, để phát hiện save-file bị sửa tay (chỉnh tiền/vàng qua công
cụ ngoài) mà không cần server validation.

## Vì sao khác biệt
Kết hợp tự nhiên với `ClampedClock` đã có — mở rộng logic "chống gian lận
local-first" đã là triết lý sẵn có của package, không phải viết lại từ đầu.
