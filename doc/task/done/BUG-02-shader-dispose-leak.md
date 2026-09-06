---
id: BUG-02
title: FragmentShader không được dispose ở AuroraBgLayer và NeonAuraLayer
type: bug
priority: P1
effort: S
verified: true
source: Claude-CLI, verify lại code thật
---

## Vị trí
- `lib/presentation/widgets/aurora_bg_layer.dart:65-67`
- `lib/presentation/widgets/neon_aura_layer.dart:65-67`

## Vấn đề
Cả 2 file đều có field `ui.FragmentShader? _shader` được gán ở `initState`/load
async, nhưng `dispose()` chỉ gọi `_ticker.dispose()`, không gọi `_shader?.dispose()`.
`FragmentShader` giữ GPU resource (native), không tự giải phóng khi widget bị
unmount nếu không dispose thủ công.

## Hậu quả
Mount/unmount lặp lại nhiều lần (chuyển màn hình qua lại, hot restart trong dev,
hoặc nhiều instance cùng lúc) sẽ rò rỉ GPU resource dần dần — có thể dẫn tới lỗi
native trên thiết bị yếu sau thời gian dài chơi.

## Đề xuất fix
Thêm `_shader?.dispose();` trong `dispose()` của cả 2 file, trước hoặc sau
`_ticker.dispose()`.

## Acceptance criteria
- [ ] Cả 2 file gọi `_shader?.dispose()` trong `dispose()`.
- [ ] Test dựng/huỷ widget nhiều lần không throw, không leak-warning (nếu có tool đo).
