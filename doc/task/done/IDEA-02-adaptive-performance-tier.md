---
id: IDEA-02
title: Adaptive performance tier tự động theo FPS runtime
type: idea
priority: exclusive
effort: L
source: agy
---

## Ý tưởng
Đo FPS thực tế trong vài giây đầu (hoặc liên tục), tự động hạ cấp/tắt
`AuroraBgLayer`/`NeonAuraLayer`/shader glow (`glow()`/`drop()` trong
`NeonTheme`) nếu máy yếu, tự bật lại nếu máy khoẻ — không cần dev tự tay cấu
hình theo từng tier thiết bị.

## Vì sao khác biệt
Hầu hết game-base kit khác để nguyên hiệu ứng cố định, không tự thích ứng
hiệu năng theo thiết bị. Kit này đã có sẵn hạ tầng shader/ticker
(`ShaderTickerLayer` nếu làm ENH-04 trước) — chỉ cần thêm lớp đo & quyết định
bật/tắt.

## Phụ thuộc
Nên làm sau ENH-04 (rút base class chung) để chỉ cần sửa 1 nơi.
