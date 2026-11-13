---
id: BUG-110
title: "restoreSlotMeta nhận id có dấu gạch dưới: deleteSlot xoá nhầm dữ liệu slot khác"
type: bug
layer: lib/core/save_slot_manager + disaster_recovery_save_export
priority: P2
effort: S
source: "Scan SDK 2026-11-12; giả thuyết của fork được kiểm và THU HẸP bằng test tái hiện"
---

## Vị trí
`lib/core/save_slot_manager.dart:267` (`restoreSlotMeta` nhận `meta.id` tuỳ ý), `:353-354` (`deleteSlot` xoá theo tiền tố `slot_<id>_`), `:337` (`keyFor` = `slot_<id>_<suffix>`), nguồn id: `lib/core/disaster_recovery_save_export.dart:276` (`slotManager.restoreSlotMeta(entry.meta)` với meta đọc từ bundle JSON).

## Tái hiện (đã chạy, test tạm đã xoá)
- ĐÚNG: khôi phục hai slot id `a` và `a_b`, ghi `keyFor('a','coins')` và `keyFor('a_b','coins')`, rồi `deleteSlot('a')`: dữ liệu `a_b` bị xoá (`slot_a_` là tiền tố của `slot_a_b_coins`).
- KHÔNG ĐÚNG (giả thuyết ban đầu của scan): id số `1` và `10` không va chạm, vì khoá luôn có dấu `_` đóng (`slot_1_` không là tiền tố của `slot_10_`).

## Điều kiện kích hoạt
Id do class tự sinh luôn là `slot_<chữ số>` nên an toàn (xem `_generateUniqueId`, comment `:239-251`). Lỗi chỉ xảy ra khi id đến từ nguồn ngoài (bundle khôi phục đã bị sửa tay, hoặc từ phiên bản/ứng dụng khác) có chứa `_` và có hai id mà một cái là tiền tố `x_` của cái kia.

## Hướng sửa
Kiểm `meta.id` trong `restoreSlotMeta` theo định dạng tự sinh `^slot_\d+$`, hoặc ít nhất không chứa `_`. `previewRestore` (validate bundle trước khi áp dụng) cũng nên từ chối id sai định dạng với `SdkFailure.validation` thay vì để lỗi chạm tới bước ghi. Chưa quyết: từ chối thẳng hay chuẩn hoá id (chuẩn hoá làm đổi khoá lưu, nên ưu tiên từ chối).

## Tiêu chí xong
Test hai id `a`/`a_b` đỏ trước sửa, xanh sau; bundle chứa id sai định dạng bị `previewRestore` từ chối; CHANGELOG ghi behavior change (restore từ chối id lạ).
