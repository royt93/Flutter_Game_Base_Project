---
id: FEAT-123
title: StreakRepairDialog — Hộp thoại phục hồi chuỗi đăng nhập lỡ dở
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 6)
---

## Vì sao cần
Người chơi rất tiếc chuỗi ngày đăng nhập dài (7-30 ngày) khi lỡ quên 1 ngày; tính năng Streak Freeze / Streak Repair (như Duolingo, Royal Match) cho phép dùng đá quý hoặc xem quảng cáo để giữ chuỗi, tăng mạnh retention D7/D30.

## Đề xuất phạm vi
Widget `StreakRepairDialog` hiển thị số ngày chuỗi bị đứt (ví dụ: chuỗi 14 ngày), hoạt họa ngọn lửa băng giá/tan băng, và 2 nút hành động caller-owned (Dùng Gem để sửa chuỗi hoặc Bỏ qua / Bắt đầu lại).

## Kiểm thử
- [x] **Unit/widget tests**: Validate streakDays >= 1 and non-negative gem price, display streak count/gems, repair/skip callback isolation, show helper dismisses on confirmation, Reduced Motion disables pulse.
- [x] **Showcase test**: Tích hợp nút mở dialog mẫu trong showcase, cập nhật trạng thái sau khi bấm sửa.
- [x] **Physical integration**: Samsung S24 Ultra (SM-S928B) opened dialog, confirmed repair callback, dismissed route cleanly. No simulator.
- [x] **Host validation**: root 2995/example 251 suites, analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] Hoạt họa nảy lửa/băng sử dụng `Transform.scale` và `CurvedAnimation`, tự giải phóng controller khi đóng dialog.
- [ ] Sustained 60 FPS benchmark not measured; standard limitation accepted.
