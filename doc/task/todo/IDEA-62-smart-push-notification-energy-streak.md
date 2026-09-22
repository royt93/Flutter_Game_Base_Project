---
id: IDEA-62
title: "Smart push notification scheduler nối ReminderService với EnergyService/DailyLoginService"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
Mở rộng `lib/core/reminder_service.dart`, dựa trên `lib/core/energy_service.dart` (`fullEnergyAtMs`-style tính toán) và `lib/core/daily_login_service.dart`.

## Hiện trạng
`ReminderService` chỉ có 1 nhắc nhở chung, không tự động tính thời điểm hồi đầy năng lượng hoặc thời điểm sắp mất streak để hẹn giờ đúng lúc.

## Vì sao cần / Hậu quả
Nhắc nhở đúng thời điểm ("năng lượng đã đầy", "sắp mất streak") tăng retention rõ rệt hơn 1 nhắc nhở chung chung — pattern kinh điển của casual/idle game.

## Đề xuất
Thêm helper tính thời điểm hồi đầy năng lượng từ `EnergyService` và thời điểm gần hết hạn streak từ `DailyLoginService`, tự động lên lịch qua `ReminderService` (huỷ lịch cũ nếu năng lượng bị tiêu tiếp trước khi tới giờ).

## Acceptance criteria
- [ ] Helper tính đúng thời điểm hồi đầy năng lượng, đặt lịch nhắc nhở qua `ReminderService`.
- [ ] Helper tính đúng thời điểm gần hết hạn streak (ví dụ vài giờ trước nửa đêm), đặt lịch nhắc nhở riêng.
- [ ] Tiêu năng lượng/claim streak trước khi tới giờ nhắc — lịch cũ được huỷ/cập nhật đúng, không nhắc nhở sai lệch.
- [ ] Test unit cho logic tính thời điểm + huỷ lịch.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-62-smart-push-notification-energy-streak.md` này trước khi làm. Đọc toàn bộ `lib/core/reminder_service.dart`, `lib/core/energy_service.dart`, `lib/core/daily_login_service.dart` trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device thật khuyến khích (verify notification thật hiện đúng lúc) không bắt buộc nếu unit test đủ chứng minh logic tính thời điểm.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng retention hợp lý, dựa trên hạ tầng đã có thật. Không trùng task nào trong `doc/task/done/`.
