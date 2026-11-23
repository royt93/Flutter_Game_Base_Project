---
id: FEAT-225
title: "QuantityStepper: nút +/- chọn số lượng có min/max, giữ để tăng nhanh"
type: feature
layer: lib/presentation/widgets/common
priority: P4
effort: S
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

`shop_item_card` chưa có chọn số lượng; dùng được trong shop, crafting, inventory.

## Phạm vi đề xuất

- `QuantityStepper(value, onChanged, min, max, step)`: `min <= max`, `step > 0` (kiểm bằng `ArgumentError`), nút bị vô hiệu ở biên, giữ nút để tăng nhanh (timer huỷ khi dispose/rời khỏi cây, tăng tốc dần có giới hạn), không bao giờ vượt biên.
- Semantics: dạng adjustable (increment/decrement) để screen reader tăng/giảm; hiển thị giá trị qua `fmtNum` (locale).
- Test: giữ nhanh dừng khi thả, không rò timer sau dispose, biên, RTL đặt nút đúng phía.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Cho gõ số trực tiếp hay chỉ +/-. Đề xuất: chỉ +/-.
