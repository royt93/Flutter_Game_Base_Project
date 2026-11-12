---
id: FEAT-201
title: "Lint màu cố định: báo Colors.* / Color(0x..) ngoài NeonTheme trong widgets"
type: feature
layer: lib/core/utils/accessibility_audit + tool
priority: P2
effort: M
source: "ENH-104: PrestigeConfirmationCard dùng Colors.orange/green, contrast 1.96 và 2.30 ở light"
---

## Vấn đề
Màu cố định bỏ qua `NeonTheme.dark` và reskin `importPalette`, nên hỏng dark mode hoặc contrast mà không ai biết cho tới khi nhìn tay.

## Phạm vi
- Thêm `AuditRuleId.hardcodedColor` vào `accessibility_audit.dart` (cùng pattern FEAT-76), chạy qua `tool/accessibility_audit_check.dart`.
- Bắt `Colors.<name>` và `Color(0x...)`; **bỏ qua**: `Colors.transparent`, `Colors.white/black` dùng làm overlay có alpha, file artwork (rương, gem) qua allowlist theo file kèm lý do.
- Baseline hiện có mở rộng cho vi phạm cũ; vi phạm mới là lỗi.

## Tiêu chí xong
- Chạy trên repo: số vi phạm cũ được ghi vào baseline, không phá `quality-gate`.
- Test đơn vị cho rule (khớp/không khớp) giống các rule hiện có.

## Không làm
Không tự đổi màu hàng loạt; mỗi file baseline mở task sửa riêng.
