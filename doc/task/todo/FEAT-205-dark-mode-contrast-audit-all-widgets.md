---
id: FEAT-205
title: "Dark-mode contrast audit: chữ thật trên nền thật của mọi widget ở NeonTheme.dark"
type: feature
layer: test/support + test/widget/common
priority: P2
effort: L
source: "ENH-103 (locked token) và ENH-104 (prestige card): token cặp đúng nhưng widget dùng màu cố định hoặc tint, validator hiện chỉ kiểm cặp token"
---

## Vấn đề
`validateNeonThemeContrast` kiểm các cặp token (ink/card, locked border/fill...) nhưng không kiểm chữ **thực sự render** trên nền **thực sự render**. ENH-104 lộ ra vì chữ `Colors.orange` trên tint alpha 0.12 chỉ đạt 1.96:1 ở light, không cặp token nào sai.

## Phạm vi
- Harness `test/support/contrast_audit.dart`: pump widget ở light và dark, duyệt cây `Text`/`Icon`, lấy màu chữ và màu nền hiệu dụng (alpha-blend các ancestor `DecoratedBox`/`Container`/`Material`), báo cặp dưới 4.5:1 (chữ) hoặc 3.0:1 (icon, cỡ lớn).
- Chỉ kiểm màu mà widget tự đặt; bỏ qua widget `Disabled` (WCAG miễn) bằng cờ.
- Báo cáo danh sách vi phạm ban đầu; mỗi vi phạm mở BUG/ENH riêng (mẫu ENH-104).

## Tiêu chí xong
- Chạy được trên nhóm widget mẫu đã sửa (prestige card xanh) và bắt lại lỗi cũ khi hoàn nguyên tạm.
- Danh sách vi phạm còn lại được ghi baseline với lý do hoặc task.

## Rủi ro
Nền có gradient/shader/ảnh không tính được bằng alpha-blend; ghi rõ giới hạn, bỏ qua nền không phải màu phẳng.

## Quan hệ
Bổ sung FEAT-201 (lint tĩnh màu cố định): lint bắt chỗ viết, audit này bắt kết quả render.
