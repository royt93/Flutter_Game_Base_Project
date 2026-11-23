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

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc widget liên quan đã có (ghi trong mục Hiện trạng) và chốt API `OnboardingCarousel` bằng 3-5 dòng trong mục "Kết quả thực hiện", chỉ code sau khi chốt.
- [ ] 2. Viết `OnboardingCarousel` + export trong `common_widgets.dart` + invariant constructor bằng `ArgumentError`.
- [ ] 3. Đọc `paginated_dots_indicator`, `OnboardingCoordinatorService`, `tutorial_sequence`; ghi ranh giới với `tutorial_sequence`.
- [ ] 4. Test: Skip/Next/Done, "đã xem" lưu qua coordinator và không hiện lần sau, `pages` ngoài 1-6 là `ArgumentError`, vuốt đúng hướng ở RTL.
- [ ] 5. Viết test widget: trạng thái chính, biên, disabled, RTL, text scale 2.0 (không tràn); chạy mutation check (bỏ logic chính, test phải đỏ).
- [ ] 6. Thêm fixture `runViewportSweep` (568x320, 640x320 @1x; 568x320 @2x text).
- [ ] 7. Thêm vào `widget_showcase_screen.dart`; chạy `flutter test` trong `example/` (showcase không tràn).
- [ ] 8. Kiểm accessibility: nhãn semantics, vùng chạm >= 44dp, `dart run tool/accessibility_audit_check.dart` pass.
- [ ] 9. Commit + push widget và test, CHƯA có golden. Chạy `gh workflow run regenerate-goldens.yml --ref main`, tải artifact `regenerated-goldens`, chỉ chép PNG của widget này vào `test/widget/goldens/goldens/` (KHÔNG chép cả artifact, KHÔNG sinh trên macOS), commit + push.
- [ ] 10. Cập nhật API snapshot + CHANGELOG: `dart run tool/api_compatibility.dart snapshot` rồi `check` (export công khai mới); ghi CHANGELOG `## Unreleased`.
- [ ] 11. Chạy cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả vào "Kết quả thực hiện", chuyển file sang `doc/task/done/` (kiểm staged diff trước khi commit, tránh race git mv).

## Tiêu chí nghiệm thu

- [ ] Lần mở sau không hiện lại khi đã bật lưu.
- [ ] Thông báo "trang x trên y" qua semantics.
- [ ] Reduced motion tắt hiệu ứng chuyển trang.

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
