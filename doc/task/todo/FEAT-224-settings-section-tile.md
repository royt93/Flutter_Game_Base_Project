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

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc widget liên quan đã có (ghi trong mục Hiện trạng) và chốt API `SettingsSection/SettingsTile` bằng 3-5 dòng trong mục "Kết quả thực hiện", chỉ code sau khi chốt.
- [ ] 2. Viết `SettingsSection/SettingsTile` + export trong `common_widgets.dart` + invariant constructor bằng `ArgumentError`.
- [ ] 3. Đọc `list_tile_row`, `section_header`, `toggle_switch`, `candy_slider` và `example/lib/screens/settings_screen.dart`; ghi widget mới chỉ là lớp ghép, không nhân đôi.
- [ ] 4. Cập nhật `settings_screen.dart` dùng widget mới; test `example/test/settings_screen_test.dart` vẫn pass (nhớ `NeonBg` không settle, dùng `pump` có thời hạn).
- [ ] 5. Viết test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0 (không tràn); chạy mutation check (bỏ logic chính, test phải đỏ).
- [ ] 6. Thêm fixture `runViewportSweep` (568x320, 640x320 @1x; 568x320 @2x text).
- [ ] 7. Thêm vào `widget_showcase_screen.dart`; chạy `flutter test` trong `example/` (showcase không tràn).
- [ ] 8. Kiểm accessibility: nhãn semantics, vùng chạm >= 44dp, `dart run tool/accessibility_audit_check.dart` pass.
- [ ] 9. Commit + push widget và test, CHƯA có golden. Chạy `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, chỉ chép PNG của widget này vào `test/widget/goldens/goldens/` (KHÔNG chép cả artifact, KHÔNG sinh trên macOS), commit + push.
- [ ] 10. Cập nhật API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 11. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả vào "Kết quả thực hiện", chuyển file sang `doc/task/done/` (kiểm staged diff trước khi commit, tránh race git mv).

## Tiêu chí nghiệm thu

- [ ] `SettingsDangerTile` luôn qua xác nhận.
- [ ] `settings_screen.dart` bớt mã tự ghép, test cũ pass.
- [ ] Text scale 2.0 không tràn.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
- `cd example && flutter test test/settings_screen_test.dart`
