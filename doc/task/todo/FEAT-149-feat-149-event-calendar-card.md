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
- [ ] **Unit test**: Validate id/title/day label không rỗng và id duy nhất.
- [ ] **Widget test**: Ba trạng thái event, current highlight, callback, empty state, semantics và Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro mở event từ lịch qua caller callback; không dùng simulator.
- [ ] **Golden test**: Upcoming/active/ended, tuần đầy đủ và empty trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Đổi tuần/rebuild khi event đang mở không gọi callback lặp hoặc giữ state cũ.
- [ ] **Network conditioning test**: N/A — widget không fetch; dữ liệu live-ops thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau scroll/unmount.
- [ ] **Frame rate / Jank test**: Scroll lịch 7+ ngày, đo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Ưu tiên scroll native, tránh ticker per event; Reduced Motion không chạy animation trang trí.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo trên thiết bị vật lý.
