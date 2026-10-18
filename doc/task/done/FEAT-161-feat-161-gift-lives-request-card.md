---
id: FEAT-161
title: GiftLivesRequestCard — Thẻ yêu cầu và gửi tặng mạng bạn bè/clan
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Social & Team Meta UI (Wave 15)
---

## Vì sao cần
Cơ chế casual kinh điển tặng mạng (lives request) thúc đẩy kết nối giữa người chơi. Card cần thể hiện ai đang xin mạng, đã gửi chưa (cooldown/sent state) và nút gửi trực quan, đáp ứng touch target chuẩn mà không phụ thuộc backend logic.

## Đề xuất phạm vi
Widget `GiftLivesRequestCard` hiển thị:
- Thông tin `GiftLivesRequest`: requestId, senderName, avatar, requestTime, state (`pending | sent | expired`).
- Nút `Send Life` với icon trái tim, đổi sang `Sent` (disabled) khi state đã gửi.
- Action callback `onSendLife(requestId)` có guard chống spam double-tap bằng `Stopwatch` monotonic clock.
- Hỗ trợ custom label/cooldown timer text do caller cung cấp.
- Presentation-only: caller quản lý kho mạng và cooldown thật.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate requestId/senderName không rỗng, guardWindow không âm, labels không rỗng; throw ArgumentError với dữ liệu không hợp lệ (`gift_lives_request_card_test.dart`).
- [x] **Widget test**: Hiển thị state pending/sent/expired, callback onSendLife, disabled state, semantics, textScale 2.0 trên viewport 320dp và Reduced Motion.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) tap Send Life chuyển pending sang sent qua caller seam (`app_boot_test.dart`); pass, không dùng simulator.
- [x] **Golden test**: `runGoldenMatrix` pending, sent và expired states trên baseline/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844 (`gift_lives_request_card_golden_test.dart`).
- [x] **Interruption test**: Tap nhanh liên tục trong guard window (500ms) chỉ kích hoạt callback 1 lần.
- [x] **Network conditioning test**: N/A — caller sở hữu transaction.
- [ ] **Memory leak & profiling test**: Widget unmount có test không phát sinh exception; chưa chạy MemoryWatchdog hoặc heap profiling riêng cho FEAT-161.
- [ ] **Frame rate / Jank test**: Chưa thu FrameTiming; thời lượng animation không chứng minh frame rate hoặc jank.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] `AnimatedContainer` 180ms chuyển màu và kích thước nút, tôn trọng `disableAnimationsOf(context)`.

## Chạy lại
```bash
flutter test test/widget/common/gift_lives_request_card_test.dart test/widget/goldens/gift_lives_request_card_golden_test.dart
cd example
flutter test test/widget_showcase_screen_test.dart --plain-name "FEAT-161"
flutter test integration_test/app_boot_test.dart -d <device-id> --dart-define=E2E_TEST=true --plain-name "FEAT-161"
```
