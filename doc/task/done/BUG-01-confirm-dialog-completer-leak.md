---
id: BUG-01
title: ConfirmDialog Completer treo vĩnh viễn khi đóng dialog bằng back button/gesture
type: bug
priority: P1
effort: S
verified: true
source: agy (Antigravity) + Claude, verify lại code thật
---

## Vị trí
`lib/presentation/widgets/common/confirm_dialog.dart:17-47`

## Vấn đề
`showConfirmDialog` tạo `Completer<bool>` và chỉ `complete()` khi người dùng bấm 1
trong 2 nút action. `NeonDialog.show` (bên dưới) dùng `showGeneralDialog` — tức
route thật được push vào `Navigator` (đã verify: `lib/presentation/widgets/neon_dialog.dart:133`).
`dismissible: false` chỉ chặn bấm ra ngoài barrier, KHÔNG chặn được nút Back vật lý
Android hay gesture back iOS — cả hai đều pop route qua `Navigator` bình thường,
bỏ qua `onTap` của 2 action, khiến `completer.future` không bao giờ complete.

## Hậu quả
Bất kỳ code nào `await showConfirmDialog(...)` rồi xử lý tiếp sẽ bị treo vĩnh viễn
nếu người dùng bấm back thay vì chọn nút — dễ gây app "đơ" ở màn hình chờ xác nhận.

## Đề xuất fix
Bọc route bằng `PopScope`/`WillPopScope` để `complete(false)` khi bị pop ngoài ý
muốn, hoặc gọi `completer.complete(false)` trong `.then()` của chính
`NeonDialog.show(...)` sau khi nó return (route đã đóng bằng cách nào cũng vậy).

## Acceptance criteria
- [ ] Bấm back/gesture khi dialog đang mở → `showConfirmDialog` future complete (giá trị `false`), không treo.
- [ ] Test mới cho case này trong `test/widget/common/` (hiện thư mục này chỉ có 1 test).
