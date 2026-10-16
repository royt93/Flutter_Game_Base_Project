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
- [x] **Unit test**: Kiểm tra `remaining`, `isCompleted`, validation 1–4 mục tiêu, target/current và ID trùng.
- [x] **Widget test**: Chuyển `current` tới `target` kích hoạt checkmark; semantics có tên và tiến độ goal.
- [x] **Showcase test**: Nút thu thập cập nhật tiến độ và hoàn tất goal.
- [x] **Physical integration**: Smoke pass trên Samsung Galaxy S24 Ultra (`R5CX613VZBR`), không dùng simulator.

## Hiệu năng & Animation
- [x] Checkmark dùng `AnimatedScale` với `NeonTheme.curvePop`; goal không đổi không rebuild.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
