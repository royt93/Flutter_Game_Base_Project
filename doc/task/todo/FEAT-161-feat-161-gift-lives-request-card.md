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
- Action callback `onSendLife(requestId)` có guard chống spam double-tap.
- Hỗ trợ custom label/cooldown timer text do caller cung cấp.
- Presentation-only: caller quản lý kho mạng và cooldown thật.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate requestId/senderName không rỗng; throw ArgumentError với dữ liệu không hợp lệ.
- [ ] **Widget test**: Hiển thị state pending/sent/expired, callback onSendLife, disabled state, semantics và textScale 2.0.
- [ ] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) tap Send Life chuyển state; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` 3 states pending/sent/expired trên baseline/dark/vi/RTL/textScale 1.3/2.0/reducedMotion, viewport 390×844.
- [ ] **Interruption test**: Tap nhanh liên tục không gọi callback trùng lặp khi đang pending.
- [ ] **Network conditioning test**: N/A — caller sở hữu transaction.
- [ ] **Memory leak & profiling test**: MemoryWatchdog và lifecycle verification sau khi card unmount.
- [ ] **Frame rate / Jank test**: Đo FrameTiming trong showcase flow.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Animation chuyển đổi trạng thái nút nảy nhẹ (SquashStretch/PressableScale) tôn trọng `reducedMotion`.
