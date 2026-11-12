---
id: IDEA-92
title: "Bootstrap chỉ phủ 7 module trong khi lib/core có 38 file chứa GetxService"
type: idea
layer: lib/core/kit_bootstrap
priority: P3
effort: M
source: "Scan SDK 2026-11-12: enum RoyCasualKitModule có 7 giá trị (kit_bootstrap.dart:15)"
---

## Quan sát
`CLAUDE.md` khuyên dùng `RoyCasualKit.initialize` thay `Get.put`, nhưng phần lớn service (wallet, energy, quest, daily login...) consumer vẫn phải tự đăng ký và tự reset, nên `resetForTesting` không dọn được chúng.

## Cần làm trước khi quyết
Phân loại từng service: cần tham số bắt buộc (không tự đăng ký được, ví dụ `OfflineProgressionService`) hay đăng ký không tham số (có thể thành module). Chỉ với nhóm sau mới đáng thêm module.

## Rủi ro
Đây có thể là thiết kế có chủ ý để consumer kiểm soát tham số; kết quả phân loại có thể là "không làm". Xác nhận với partner trước khi mở rộng enum (thay đổi API công khai).

## Ghi chú
Đếm `onClose`/`dispose` bằng grep ở ít nhất 12 service cho 0 lần khớp, nhưng chưa chứng minh service nào giữ timer/stream thật; không tách task riêng cho đến khi có bằng chứng rò.
