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

## Đã làm (2026-11-13): pha 1, rule mức info
`AuditRuleId.hardcodedString`: `Text('...')` và đối số `label:`/`title:`/`message:`/`hintText:`/`semanticLabel:`/`tooltip:` chứa chuỗi thường có >= 3 chữ cái, không nội suy `$`, bỏ qua định danh thường kiểu khoá dịch (`level_up_skip`), ký hiệu và comment. Trên repo: **23 file** bị báo, trong đó `debug_qa_overlay.dart` chiếm 44 chuỗi (dev-only, cần baseline). Mặc định audit vẫn xanh (mức info không chặn CI); CLI mặc định chỉ đếm các finding dưới ngưỡng và in "N lower-severity finding(s) not shown", `--minSeverity=info` để liệt kê. 2 test cho rule; test CLI cập nhật.
Việc còn lại: phân loại 23 file (mặc định tiếng Anh hợp lệ của tham số override, hay lỗi thật như `streak_shield_card` 'Current Streak'/'Freeze Shields' không ghi đè được), baseline `debug_qa_overlay`, rồi mới cân nhắc nâng lên warning.

## Tiêu chí xong
- Báo cáo danh sách baseline; mỗi mục hoặc có task thêm tham số override (mẫu ENH-105) hoặc nằm trong allowlist có lý do.

## Rủi ro
Nhiều false positive (tên riêng, ký hiệu); vì thế để ưu tiên thấp và `info` trước.
