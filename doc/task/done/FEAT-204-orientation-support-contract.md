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

## Quyết định (2026-11-13, người dùng)
SDK cam kết landscape cho TOÀN BỘ widget trong `common/`, ngoại lệ phải ghi kèm lý do. Không công bố cam kết trong `INTEGRATION_GUIDE` hay `CLAUDE.md` cho tới khi FEAT-200 phủ hết hoặc liệt kê rõ widget chưa kiểm.

## Tiến độ (2026-11-17)
- [x] Chốt vị trí công tắc xoay: `DebugQaOverlay` (dev/profile-only), không đưa vào Settings.
- [x] Đối chiếu `common_widgets.dart`: 170 public widget class; toàn 170 có fixture trong `viewport_sweep_test.dart`, gồm landscape 568×320/640×320 ở baseline. Text scale 2× được kiểm ở landscape 568×320 và viewport compact 320×480. `WheelPointerClicker` có case trực tiếp.
- [x] Thêm `Allow landscape` toggle vào tab State. Mặc định tắt; bật gửi landscapeLeft/landscapeRight, tắt gửi portraitUp. Platform-channel widget test pass.
- [x] Consumer/contributor docs ghi viewport đã kiểm và nói rõ sweep không chứng minh thiết bị xoay thực tế.
- [x] Smoke-test TECNO KJ7 (Android 14, 2026-11-17): khởi động portrait (`ROTATION_0`); Debug QA (nhấn giữ góc trên phải) → State → `Allow landscape` bật thì `ROTATION_90` / `SCREEN_ORIENTATION_USER_LANDSCAPE`, tắt thì về `SCREEN_ORIENTATION_PORTRAIT`; bật rồi force-stop và mở lại thì app trở lại portrait.

## (giữ nguyên) Câu hỏi ban đầu
- SDK cam kết landscape cho toàn bộ widget hay chỉ nhóm dialog/overlay/HUD?
- Công tắc xoay đặt ở `DebugQaOverlay` (dev-only) hay Settings (người dùng thấy)?

## Tiêu chí xong
Có chính sách ghi trong docs, sweep landscape phủ nhóm cam kết, example xoay được qua công tắc dev.

## Phụ thuộc
FEAT-200.
