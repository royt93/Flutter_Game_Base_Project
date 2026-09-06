---
id: FEAT-18
title: ConfettiOverlay — hiệu ứng pháo giấy/particle burst khi thắng
type: feature
priority: P1
effort: M
source: user pick (đã chốt trong phiên chọn widget mới)
---

## Vì sao cần
Casual game nào cũng có màn ăn mừng khi thắng/hoàn thành level — kit hiện
chưa có widget particle burst nào (grep xác nhận không có `Confetti*`/`Particle*`
trong `lib/presentation/widgets/`).

## Đề xuất phạm vi
`ConfettiOverlay` — `StatefulWidget` dùng `CustomPainter` + `Ticker` (tái dùng
đúng pattern throttle đã có ở `AuroraBgLayer`/`NeonAuraLayer`, nhớ dispose
đúng — xem BUG-02 để không lặp lại lỗi tương tự): N mảnh giấy màu rơi/bung ra
từ 1 điểm hoặc toàn màn hình, tự dừng và ẩn sau X giây, không lặp vô hạn (khác
`NeonBg`/`AuroraBgLayer` vốn chạy liên tục).

## Yêu cầu test (bắt buộc — theo yêu cầu chung của mọi widget mới)
- **Unit test**: logic tính vị trí/vận tốc từng particle theo thời gian (hàm
  thuần, tách khỏi widget nếu có thể) — không cần dựng UI.
- **Widget test**: dựng `ConfettiOverlay`, `pump()` qua vài frame, assert số
  lượng particle hiển thị đúng, widget tự ẩn/dispose đúng sau thời lượng cấu
  hình (dùng `TickerMode(enabled: false)` hoặc bounded `pump(Duration)` theo
  đúng gotcha `NeonBg` đã ghi trong CLAUDE.md — không dùng `pumpAndSettle`).
- **Integration test**: thêm 1 case trong `example/integration_test/` dựng
  `ConfettiOverlay` trong 1 màn hình thật (ví dụ demo trong
  `WidgetShowcaseScreen`), verify không crash/không leak qua vài lần
  trigger liên tiếp trên thiết bị/emulator thật.

## Demo
Thêm 1 section "Confetti" trong `example/lib/screens/widget_showcase_screen.dart`
với nút "Trigger" để xem trực tiếp.

## Acceptance criteria
- [ ] Trigger nhiều lần liên tiếp không leak `Ticker`/`AnimationController` (dispose đúng).
- [ ] Đủ 3 loại test (unit/widget/integration) + demo trong showcase.
