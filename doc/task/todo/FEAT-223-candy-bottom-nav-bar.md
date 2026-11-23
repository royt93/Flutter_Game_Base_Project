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
