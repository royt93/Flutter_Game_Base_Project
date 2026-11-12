---
id: ENH-104
title: "PrestigeConfirmationCard chữ cảnh báo/badge dùng màu cố định, thiếu contrast ở light"
type: enhancement
layer: lib/widgets/common
priority: P2
effort: S
source: "Audit UI 2026-11-12; đo bằng contrastRatio"
---

## Hiện trạng (đo thật)
Chữ `Colors.orange` trên chip tint: 1.96:1 (light), 6.34:1 (dark). Chữ `Colors.green` trên badge: 2.30:1 (light), 4.38:1 (dark). Ngưỡng AA 4.5:1.

## Đã làm
Chữ và icon cảnh báo dùng `NeonTheme.ink`; nền/viền tint giữ màu cảnh báo. Test `ENH-104` kiểm 4.5:1 ở cả hai theme.

## Ghi chú / việc còn lại
Golden `wave23_prestige_*` (ready/locked) sẽ đổi màu chữ chip và badge, nên CI "Test host" có thể đỏ cho đến khi chạy `regenerate-goldens.yml` và nhập PNG mới (không chạy trên macOS).
