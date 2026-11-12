---
id: FEAT-204
title: "Hợp đồng orientation: SDK nói rõ widget nào hỗ trợ landscape và có test chứng minh"
type: feature
layer: docs + test + example
priority: P2
effort: M
source: "BUG-103, BUG-104, PauseOverlay overflow: lỗi landscape chỉ lộ khi mở khoá tay vì example khoá portrait ở main.dart:56"
---

## Vấn đề
Example khoá portrait (`example/lib/main.dart:56`), nên cả bộ widget không bao giờ được chạy landscape trong demo. Consumer game ngang (match-3 landscape, runner) không biết widget nào an toàn. Ba lỗi cùng lớp đã lộ trong một phiên mà không test nào bắt.

## Phạm vi
1. Quyết định chính sách và ghi vào `CLAUDE.md` + `doc/INTEGRATION_GUIDE.md`: widget `common/` hỗ trợ cả hai orientation trừ khi nằm trong danh sách ngoại lệ có lý do.
2. Dùng `runViewportSweep` (FEAT-200) cho 568x320 và 640x320 làm bằng chứng; danh sách ngoại lệ nằm cạnh sweep.
3. Example: thêm công tắc dev (trong `DebugQaOverlay` hoặc Settings) bật xoay tự do để kiểm tay, mặc định vẫn portrait.

## Câu hỏi cần quyết định
- SDK cam kết landscape cho toàn bộ widget hay chỉ nhóm dialog/overlay/HUD?
- Công tắc xoay đặt ở `DebugQaOverlay` (dev-only) hay Settings (người dùng thấy)?

## Tiêu chí xong
Có chính sách ghi trong docs, sweep landscape phủ nhóm cam kết, example xoay được qua công tắc dev.

## Phụ thuộc
FEAT-200.
