---
id: BUG-110
title: "SaveSlotManager.restoreSlotMeta không kiểm id, có thể làm deleteSlot xoá nhầm slot khác (CHƯA TÁI HIỆN)"
type: bug
layer: lib/core/save_slot_manager
priority: P3
effort: S
source: "Scan SDK 2026-11-12; chỉ đọc code, độ tin cậy suy đoán"
---

## Vị trí
`lib/core/save_slot_manager.dart:267-275` (`restoreSlotMeta` nhận `meta.id` tuỳ ý) và `:344-352` (`deleteSlot` xoá theo tiền tố `slot_<id>_`); comment `:335-337` giả định mọi id do class tự sinh.

## Giả thuyết
Id khôi phục từ bản backup như `1` cho tiền tố `slot_1_`, trùng phần đầu của `slot_10_...`, nên `deleteSlot('1')` có thể xoá dữ liệu của slot `10`. Chưa chạy test dựng lại điều này.

## Việc đầu tiên
Viết test tái hiện (lưu hai slot id `1` và `10`, xoá `1`, kiểm slot `10` còn nguyên). Nếu không tái hiện được thì đóng task với kết luận ghi rõ. Nếu có: kiểm id theo định dạng class tự sinh khi restore, hoặc đổi tiền tố xoá thành khớp chính xác `slot_<id>_` kèm kết thúc rõ ràng.
