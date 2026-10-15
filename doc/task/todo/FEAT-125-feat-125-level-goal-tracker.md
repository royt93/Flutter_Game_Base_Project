---
id: FEAT-125
title: LevelGoalTracker — Thanh HUD mục tiêu màn chơi kèm checkmark nảy
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 6)
---

## Vì sao cần
Trong game match-3 và puzzle, người chơi cần liên tục theo dõi tiến độ các mục tiêu (ví dụ: thu thập 15 dâu tây, phá 8 ô băng); khi hoàn thành 1 mục tiêu, icon chuyển thành dấu tích xanh nảy tạo cảm giác thoả mãn cao.

## Đề xuất phạm vi
Widget `LevelGoalTracker` hiển thị danh sách 1-4 mục tiêu (`GoalItem`: icon/widget, target, current, completed), tự động chuyển số đếm còn lại và bật nảy checkmark khi `current >= target`.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra tính toán số lượng còn thiếu (`remaining`), trạng thái `isCompleted` và validate danh sách mục tiêu hợp lệ.
- [ ] **Widget test**: Cập nhật `current` đạt `target` kích hoạt checkmark nảy, kiểm tra semantics accessibility đọc rõ tiến độ mục tiêu.
- [ ] **Showcase test**: Demo thanh mục tiêu có nút bấm tăng tiến độ trong showcase, hoàn thành mục tiêu cập nhật UI chính xác.
- [ ] **Physical integration**: Kiểm tra hiển thị và phản hồi trên thiết bị thật TECNO KJ7 / physical device, không dùng simulator.

## Hiệu năng & Animation
- [ ] Checkmark nảy sử dụng `AnimatedScale` với đường cong `NeonTheme.curvePop`, không rebuild các item chưa đổi số.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
