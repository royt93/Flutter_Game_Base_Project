---
id: BUG-109
title: "signExport/verifyAndStrip chấp nhận secret rỗng, chữ ký mất tác dụng mà không báo"
type: bug
layer: lib/core/save_integrity
priority: P2
effort: S
source: "Scan SDK 2026-11-12; đã tái hiện bằng test tạm"
---

## Vị trí
`lib/core/save_integrity.dart:42` (`signExport`), `:54` (`verifyAndStrip`): không kiểm tra `secret`.

## Tái hiện (đã chạy)
`signExport({'a': 1}, '')` thành công và trả bản có `_checksum`. HMAC khoá rỗng ai cũng tính lại được, nên người sửa save có thể ký lại, và chức năng chống sửa save mất tác dụng mà không có dấu hiệu nào. `BackupRestorePanel` nhận `secret` từ consumer nên cấu hình thiếu secret sẽ không bị phát hiện.

## Hướng sửa
`ArgumentError.value(secret, 'secret', 'must not be empty')` trong cả `signExport` và `verifyAndStrip` (cùng quy ước ENH-85 cho giá trị do người gọi cấu hình). Chưa xác định: có nên đặt độ dài tối thiểu hay không (hỏi người quyết định, vì có thể làm hỏng consumer đang dùng secret ngắn).

## Tiêu chí xong
Test: secret rỗng ném `ArgumentError` ở cả hai hàm; mọi test hiện có dùng secret không rỗng vẫn xanh; CHANGELOG ghi mục behavior change.

## Gộp
Nên làm cùng BUG-108 (cùng file, cùng quy ước kiểm tra đầu vào).
