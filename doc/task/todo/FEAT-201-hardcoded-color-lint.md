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

## Tiến độ (2026-11-12)
- [x] Rule `AuditRuleId.hardcodedColor` trong `lib/core/utils/accessibility_audit.dart`, chạy qua `tool/accessibility_audit_check.dart`. Bỏ qua `Colors.transparent`, mọi `Colors.white*`/`Colors.black*` (scrim), token `NeonTheme.*` và comment.
- [x] Baseline: 9 file, mỗi mục có lý do thật (artwork rương, huy chương, scrim, viền debug, tint không chứa chữ). Hai mục đã ghi hướng sửa: `team_roster_list.dart` (redAccent nút xoá, theo FEAT-205) và `neon_icon.dart` (`Colors.grey` disabled, nên đổi sang `NeonTheme.muted`).
- [x] Test rule: 3 test trong `accessibility_audit_test.dart`; test "mọi rule" cập nhật.
- [ ] Mở ENH cho hai mục baseline có hướng sửa.

## Tiêu chí xong
- Chạy trên repo: số vi phạm cũ được ghi vào baseline, không phá `quality-gate`.
- Test đơn vị cho rule (khớp/không khớp) giống các rule hiện có.

## Không làm
Không tự đổi màu hàng loạt; mỗi file baseline mở task sửa riêng.
