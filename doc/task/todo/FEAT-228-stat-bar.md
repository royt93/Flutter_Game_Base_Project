---
id: FEAT-228
title: "StatBar: thanh chỉ số ngang (HP, mana, XP) có nhãn, giá trị/tối đa, hiệu ứng trễ khi mất"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

Đã đọc để chốt ranh giới (không trùng): `EnergyBar` là hàng icon (tim) theo `currentEnergy/maxEnergy`, `ProgressBarStars` là thanh tiến độ có sao + pháo, `CircularProgressRing` là vòng tròn. Chưa có thanh chỉ số ngang tổng quát cho HP/mana/XP.

## Phạm vi đề xuất

- `StatBar(value, max, label?, color, showValue)`: `max > 0`, `value` kẹp trong [0, max] (kiểm bằng `ArgumentError` cho `max`), thanh "trễ" (phần vừa mất giảm chậm sau thanh chính) và phần hồi, tôn trọng reduced motion (không hiệu ứng thì nhảy thẳng).
- Semantics: đọc "<nhãn> <value> trên <max>", không đọc từng bước hoạt ảnh; hiển thị số qua `fmtNum`.
- Test: kẹp biên, giá trị = 0 và = max, đổi giá trị liên tiếp, RTL (thanh đầy từ bên phải), text scale 2x.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Có phiên bản dọc (cho HUD cạnh màn) hay chỉ ngang. Đề xuất: ngang trước.
