---
id: FEAT-226
title: "OnboardingCarousel: vài trang giới thiệu + dots + Skip/Next/Done, lưu 'đã xem' qua OnboardingCoordinatorService"
type: feature
layer: lib/presentation/widgets/common
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-23 (widget cho app casual), owner chọn đưa vào backlog"
---

Kit có `paginated_dots_indicator`, `onboarding_flow_queue_card`, `OnboardingCoordinatorService` và `tutorial_sequence` (hướng dẫn spotlight trong game), nhưng không có widget ghép các trang giới thiệu lần đầu mở. Cần ranh giới rõ với `tutorial_sequence` (spotlight trên UI thật) để khỏi trùng.

## Phạm vi đề xuất

- `OnboardingCarousel(pages, onFinished, storageKey?)`: `pages` 1-6 (kiểm `ArgumentError`), mỗi trang là widget do app cấp (kit không giữ nội dung), dots, nút Skip/Next/Done, vuốt, tôn trọng reduced motion.
- Tuỳ chọn ghi "đã xem" qua `OnboardingCoordinatorService` (key do app đặt), mở lần sau thì không hiện; không tự đọc service nếu app không bật.
- Semantics: thông báo "trang x trên y", nút có nhãn; RTL đảo hướng vuốt đúng; text scale 2x vẫn cuộn được nếu nội dung dài.
- Cập nhật example để dùng (vd ở lần mở Home đầu tiên) bằng tối thiểu.

## Chuẩn của repo cho widget mới (bắt buộc)

- Đặt trong `lib/presentation/widgets/common/`, export qua `common_widgets.dart`, thêm vào `example/lib/screens/widget_showcase_screen.dart` (tài liệu sống) và cập nhật `tool/api_snapshot.json` + CHANGELOG.
- Fixture `runViewportSweep` (568x320 và 640x320 landscape, 1x text; 568x320 ở 2x text) cho layout/tràn.
- Golden: commit widget + test trước, sinh baseline bằng workflow `regenerate-goldens.yml` trên Linux, chỉ chép PNG thay đổi (KHÔNG sinh trên macOS).
- Accessibility: nhãn semantics đúng, vùng chạm >= 44-48dp, kiểm tra RTL, `tool/accessibility_audit_check.dart` pass; thiết bị thật (S24U) chỉ khi cần.
- Mọi invariant constructor kiểm bằng `ArgumentError`, không chỉ `assert` (ENH-85). Không thêm dependency.

## Câu hỏi mở

Có hiệu ứng parallax giữa trang hay phẳng. Đề xuất: phẳng.
