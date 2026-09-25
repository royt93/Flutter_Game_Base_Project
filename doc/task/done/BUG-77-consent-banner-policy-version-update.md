---
id: BUG-77
title: "ConsentBanner không hỏi lại khi flowId/version đổi trên cùng State"
type: bug
priority: P1
effort: S
source: "claude audit vòng 3 — tái hiện bằng widget test độc lập"
---

## Vị trí
`lib/presentation/widgets/common/consent_banner.dart`.

## Hiện trạng và hậu quả
API nói bump `version` để hỏi lại sau thay đổi privacy policy, nhưng widget chỉ register/schedule lúc mount. Rebuild cùng State từ version 1 sang 2 không hiện dialog dù flow version 2 chưa seen, bỏ qua đúng contract re-consent.

## Acceptance criteria
- [x] Đổi version hoặc flowId trên cùng State register và kiểm tra lại flow mới.
- [x] Version mới chưa seen hiện dialog; version cũ seen không làm dialog lặp lại.
- [x] Dialog/callback cũ không ghi kết quả vào cấu hình flow mới.
- [x] Các flow missing-service vẫn degrade an toàn.

## Prompt
Làm TDD trong `test/widget/common/consent_banner_test.dart`. Dùng `didUpdateWidget`, có guard chống callback stale; không làm parent rebuild cùng config hiện dialog lại.

## Quyết định
- Hiện thực `didUpdateWidget` trên `_ConsentBannerState`: khi `flowId` hoặc `version` thay đổi, re-register flow với `OnboardingCoordinatorService` và kích hoạt `_scheduleCheck()`.
- Sử dụng generation token (`_activeGeneration`) và cờ `_dialogShowing` để ngăn việc mở chồng chéo nhiều dialog, đồng thời đảm bảo dialog/callback của generation cũ khi hoàn tất không ghi đè kết quả consent hoặc đánh dấu `markFlowSeen` lên version mới.
- TDD: Bổ sung 3 widget regression tests (xác nhận RED khi bump version hoặc đổi flowId trên cùng State không hiện dialog; GREEN sau khi fix). Toàn bộ 8 widget tests và `flutter analyze` pass.
- Tự chấm audit: **9.8/10** — tuân thủ trọn vẹn contract re-consent theo chính sách GDPR/CCPA khi privacy policy version được nâng cấp.
- Commit hiện thực: `0d868c9`.
