---
id: BUG-09
title: StorageService.getDouble default = 1.0 không nhất quán với các getter khác
type: bug
priority: P2
effort: S
verified: true
source: Claude (fork nội bộ), verify lại code thật
---

## Vị trí
`lib/core/storage_service.dart:153`

## Vấn đề
`getInt`/`getBool`/`getString` đều mặc định về giá trị "rỗng" hợp lý theo kiểu
(0/false/null), riêng `getDouble(String key, {double def = 1.0})` mặc định
**1.0**. Dev quên truyền `def:` khi đọc 1 giá trị double mới (ví dụ volume,
scale) rất dễ nhận nhầm `1.0` là "giá trị thật đã lưu" thay vì "chưa từng lưu".

## Đề xuất fix
Đổi default về `0.0` cho nhất quán, rà lại toàn bộ call site hiện tại của
`getDouble` (nếu có) để truyền `def:` tường minh nếu chúng thực sự cần mặc
định khác 0.

## Acceptance criteria
- [ ] `getDouble` mặc định `0.0`.
- [ ] Không có call site nào âm thầm đổi hành vi (rà bằng grep `getDouble(`).
