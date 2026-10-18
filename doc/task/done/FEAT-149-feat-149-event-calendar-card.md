---
id: FEAT-149
title: EventCalendarCard — Lịch event tuần với trạng thái mở và kết thúc
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Shop, Events & Retention UI (Wave 12)
---

## Vì sao cần
Game live-ops có event luân phiên; người chơi cần xem lịch tuần, event sắp mở, đang diễn ra và đã kết thúc trong một khu vực dễ đọc. Mốc thời gian cần do caller cung cấp để widget không tự suy đoán timezone hoặc lịch server.

## Đề xuất phạm vi
Widget `EventCalendarCard` hiển thị:
- Các `EventCalendarItem` theo ngày với nhãn thời gian caller format sẵn, icon/ảnh, tiêu đề và trạng thái (`upcoming`, `active`, `ended`).
- Điểm nhấn cho ngày/event hiện hành; action mở event gọi `onOpen(eventId)`.
- Empty state và danh sách scroll/lazy nếu lịch vượt kích thước card.
- Không tự tính lịch UTC/local hoặc tải cấu hình; caller chuyển timestamp thành label/status.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate id/day/title/time labels không rỗng và id duy nhất (`event_calendar_card_test.dart`, 4 test pass).
- [x] **Widget test**: Upcoming/active/ended states, caller order, active/upcoming callback, ended không mở, empty state, semantics, textScale 2.0.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) hiển thị lịch trên showcase và active event gọi caller callback; không dùng simulator.
- [x] **Golden test**: Week states và empty trên baseline/dark/vi/RTL/textScale/reducedMotion.
- [x] **Interruption test**: N/A — widget không có timer/controller hoặc modal nội bộ.
- [x] **Network conditioning test**: N/A — widget không fetch; dữ liệu live-ops thuộc caller.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-149.
- [ ] **Frame rate / Jank test**: CHƯA ĐO lịch 7+ ngày trên device.
- [x] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [x] Danh sách render lazy bằng `ListView.builder`; không có ticker per event; không thêm animation nên Reduced Motion không cần nhánh riêng.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.
