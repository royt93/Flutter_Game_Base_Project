---
id: FEAT-13
title: Remote config / feature flag đơn giản
type: feature
priority: P2
effort: M
source: fork nội bộ
---

## Vì sao cần
Chưa có cách nào bật/tắt tính năng hoặc chỉnh tham số (giá IAP, độ khó, tốc độ
hồi năng lượng) mà không cần release lại app.

## Đề xuất phạm vi
1 service đọc JSON config: ưu tiên từ network (nếu có), fallback về bản JSON
đóng gói sẵn trong asset nếu network fail/chưa fetch xong — không phụ thuộc
Firebase Remote Config cụ thể (giữ package trung lập).

## Acceptance criteria
- [ ] Network fail → vẫn có giá trị fallback hợp lệ từ asset, không throw.
- [ ] Test đọc cả 2 nguồn (mock network response + asset fallback).
