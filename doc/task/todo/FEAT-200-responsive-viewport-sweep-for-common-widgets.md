---
id: FEAT-200
title: "Responsive viewport sweep: mọi widget trong common/ không overflow ở màn nhỏ và landscape"
type: feature
layer: test/support + test/widget/common
priority: P1
effort: L
source: "BUG-103, BUG-104 + PauseOverlay overflow cùng một lớp lỗi; chưa có gate bắt"
---

## Vấn đề
`golden_matrix.dart` (FEAT-69) quét dark/locale/RTL/textScale/reducedMotion nhưng **mọi combo dùng một viewport mặc định**. Vì vậy PauseOverlay (landscape), GameDemo FAB (landscape) và StreakRepairDialog (320dp) đều lọt qua và chỉ lộ khi test tay.

## Phạm vi
- Thêm `ViewportCase` (320x480, 360x640, 568x320, 640x320, tablet 768x1024) vào `test/support/`, tách khỏi `GoldenMatrixCase` để không nhân số golden.
- Test sweep chỉ kiểm "không `takeException`, panel nằm trong viewport", **không so golden**.
- Mỗi widget cần fixture dựng tối thiểu; widget lấy từ barrel `common_widgets.dart`.

## Pha
1. Khung + 5 widget dạng dialog/overlay (PauseOverlay, StreakRepairDialog, ConfirmDialog, RewardPopup, PrestigeConfirmationCard) làm mẫu.
2. Phần còn lại của common/; widget cố tình không hỗ trợ viewport nhỏ phải có lý do ghi trong allowlist.
3. Gắn vào CI (`flutter test` root đã chạy, không cần job mới).

## Tiến độ
- [x] Pha 1 khung: `test/support/viewport_sweep.dart` (`ViewportCase`, `runViewportSweep`) và `test/widget/common/viewport_sweep_test.dart` với StreakRepairDialog (1x và 2x text), PrestigeConfirmationCard, RewardPopup, SupportDiagnosticsCard. Đã chứng minh: hoàn nguyên tạm bug width 320 thì 2 test đỏ.
- [ ] Mở rộng sang phần còn lại của `common/` (khoảng 165 widget): làm theo nhóm, widget cố tình không hỗ trợ viewport nhỏ phải có lý do trong allowlist.
- Ghi chú: `PauseOverlay` đã có test landscape riêng; `showConfirmDialog` là route, không phải widget nên ngoài phạm vi sweep.

## Tiêu chí xong
- Sweep xanh; allowlist có lý do từng dòng.
- Thử đưa lại bug cũ (width cố định 320) thì test đỏ.

## Rủi ro
Có thể lộ nhiều lỗi cũ cùng lúc; xử lý bằng cách tách BUG-xxx riêng cho mỗi widget lỗi, không sửa gộp.
