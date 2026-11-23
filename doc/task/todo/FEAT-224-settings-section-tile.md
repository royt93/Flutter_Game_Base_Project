---
id: FEAT-224
title: "SettingsSection + SettingsTile: nhóm cài đặt (switch, slider, chọn, nút nguy hiểm có xác nhận)"
type: feature
layer: lib/presentation/widgets/common
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

Mỗi app tự dựng màn cài đặt từ `toggle_switch`, `candy_slider`, `list_tile_row`, `section_header`. Có nguy cơ trùng với `list_tile_row`/`section_header`: việc ĐẦU TIÊN là đọc hai widget đó và `example/lib/screens/settings_screen.dart` rồi chốt widget mới chỉ là lớp ghép (nhóm + hàng có điều khiển bên phải + hàng nguy hiểm), không nhân đôi.

## Phạm vi đề xuất

- `SettingsSection(title, children)` và các hàng: `SettingsSwitchTile`, `SettingsSliderTile`, `SettingsChoiceTile` (mở bottom sheet chọn), `SettingsDangerTile` (luôn qua `ConfirmDialog`, ví dụ xoá dữ liệu, dùng `HoldToConfirmButton` nếu hợp).
- Nhãn + mô tả phụ, trạng thái disabled, semantics đúng cho switch/slider, RTL, text scale 2x không tràn.
- Cập nhật `settings_screen.dart` của example để dùng, chứng minh thay được mã tự ghép.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Hàng chọn ngôn ngữ có gắn thẳng `LocaleService` hay chỉ callback. Đề xuất: callback (widget không biết service).
