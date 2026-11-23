---
id: FEAT-227
title: "CandyCheckbox + CandyDropdown: hoàn thiện bộ form candy"
type: feature
layer: lib/presentation/widgets/common
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

Quét `lib`: không có checkbox hay dropdown; bộ form candy chỉ có `candy_radio_group`, `candy_text_field`, `candy_slider`, `toggle_switch`.

## Phạm vi đề xuất

- `CandyCheckbox(value, onChanged, label)`: có nhãn bấm được, trạng thái tri-state tuỳ chọn, disabled, semantics checkbox đúng (checked/mixed), vùng chạm >= 44dp gồm cả nhãn.
- `CandyDropdown<T>(items, value, onChanged)`: trên màn nhỏ mở `BottomSheetPanel` (đã có) thay vì menu nổi, để không tràn khung và đúng vùng chạm; hiển thị giá trị chọn, placeholder, disabled.
- Test: chọn/bỏ chọn, tri-state, danh sách rỗng (`ArgumentError` hoặc trạng thái rỗng rõ ràng, chốt khi làm), RTL, text scale 2x.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Dropdown có tìm kiếm (`candy_search_bar` đã có) khi nhiều mục hay không. Đề xuất: không ở bản đầu.
