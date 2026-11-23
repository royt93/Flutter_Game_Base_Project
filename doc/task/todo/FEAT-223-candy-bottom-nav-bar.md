---
id: FEAT-223
title: "CandyBottomNavBar: thanh điều hướng dưới 3-5 mục, badge số, hiệu ứng chọn, RTL"
type: feature
layer: lib/presentation/widgets/common
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

Kit có `segmented_tab_bar` nhưng không có điều hướng dưới (quét `widgets/common`: không bottom nav). App casual thường có Home/Shop/Quests/Profile.

## Phạm vi đề xuất

- `CandyBottomNavBar(items, currentIndex, onChanged)` 3-5 mục (ngoài khoảng đó `ArgumentError`), mỗi mục icon + nhãn + `badgeCount` tuỳ chọn (tái dùng `badge_dot`/`icon_badge_button` nếu hợp), hiệu ứng chọn có tôn trọng reduced motion, theme candy qua `NeonTheme`.
- Semantics: mỗi mục là button có trạng thái selected, nhãn gồm số badge; thứ tự theo hướng đọc, RTL đảo đúng.
- Không tự quản lý route (app tự đổi trang), không phụ thuộc GetX navigation.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Cho phép mục giữa nổi bật (nút hành động lớn) hay chỉ thanh phẳng ở bản đầu. Đề xuất: phẳng.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc widget liên quan đã có (ghi trong mục Hiện trạng) và chốt API `CandyBottomNavBar` bằng 3-5 dòng trong mục "Kết quả thực hiện", chỉ code sau khi chốt.
- [ ] 2. Viết `CandyBottomNavBar` + export trong `common_widgets.dart` + invariant constructor bằng `ArgumentError`.
- [ ] 3. Test `ArgumentError` khi số mục ngoài 3-5; badge hiển thị trong nhãn semantics; mục chọn có trạng thái selected.
- [ ] 4. Viết test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0 (không tràn); chạy mutation check (bỏ logic chính, test phải đỏ).
- [ ] 5. Thêm fixture `runViewportSweep` (568x320, 640x320 @1x; 568x320 @2x text).
- [ ] 6. Thêm vào `widget_showcase_screen.dart`; chạy `flutter test` trong `example/` (showcase không tràn).
- [ ] 7. Kiểm accessibility: nhãn semantics, vùng chạm >= 44dp, `dart run tool/accessibility_audit_check.dart` pass.
- [ ] 8. Commit + push widget và test, CHƯA có golden. Chạy `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, chỉ chép PNG của widget này vào `test/widget/goldens/goldens/` (KHÔNG chép cả artifact, KHÔNG sinh trên macOS), commit + push.
- [ ] 9. Cập nhật API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 10. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả vào "Kết quả thực hiện", chuyển file sang `doc/task/done/` (kiểm staged diff trước khi commit, tránh race git mv).

## Tiêu chí nghiệm thu

- [ ] 3-5 mục, đổi mục gọi `onChanged` đúng chỉ số.
- [ ] RTL đảo thứ tự đúng.
- [ ] Vùng chạm mỗi mục >= 48dp.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
