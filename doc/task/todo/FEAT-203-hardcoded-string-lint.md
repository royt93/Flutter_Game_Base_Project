---
id: FEAT-203
title: "Lint chuỗi hard-code: Text('literal') trong widgets phải qua tham số hoặc .tr"
type: feature
layer: lib/core/utils/accessibility_audit + tool
priority: P3
effort: M
source: "ENH-105: 3 panel có chuỗi tiếng Anh không ghi đè được"
---

## Vấn đề
Consumer tiếng Việt thấy chuỗi tiếng Anh trong panel vì không có tham số override. Quy ước hiện tại chỉ nằm trong code mẫu.

## Phạm vi
- Rule mới: `Text('<chữ cái>...')`/`Semantics(label: '...')` có literal chứa chữ nhưng không đến từ tham số constructor hoặc `.tr`.
- Bỏ qua: file `debug_*`, `DebugQaOverlay`, `live_frame_graph` (dev-only), chuỗi chỉ ký hiệu/số/đơn vị.
- Mức `info` ở pha 1 để xem số lượng; chỉ nâng `warning` khi baseline gọn.

## Tiêu chí xong
- Báo cáo danh sách baseline; mỗi mục hoặc có task thêm tham số override (mẫu ENH-105) hoặc nằm trong allowlist có lý do.

## Rủi ro
Nhiều false positive (tên riêng, ký hiệu); vì thế để ưu tiên thấp và `info` trước.
