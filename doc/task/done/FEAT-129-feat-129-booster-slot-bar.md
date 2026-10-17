---
id: FEAT-129
title: BoosterSlotBar — Hàng ô booster kèm badge số lượng, cooldown và trạng thái khoá
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 7)
---

## Vì sao cần
Booster (búa, bom, xáo trộn, thêm nước đi) là cơ chế kiếm tiền và giữ chân cốt lõi của game match-3 và puzzle. Hàng ô booster ngay trên bàn chơi cần hiển thị rõ số lượng còn lại, trạng thái đang hồi (cooldown), ô bị khoá chưa mở, và phản hồi tap rõ ràng.

## Đề xuất phạm vi
Widget `BoosterSlotBar` hiển thị danh sách 1-5 ô booster (`BoosterSlot`: id, icon/widget, count, cooldown còn lại, locked), gồm:
- Badge số lượng ở góc ô; ô hết hàng hiển thị dấu (+) mời mua thêm thay vì số 0.
- Ô đang cooldown hiển thị vòng đếm ngược và khoá tap; ô bị khoá hiển thị icon ổ khoá.
- Callback `onSlotTap(id)` và `onEmptySlotTap(id)` do caller sở hữu, widget không tự trừ số lượng.
- Hiệu ứng nảy khi tap và khi số lượng tăng; Reduced Motion bỏ qua hiệu ứng nảy.
- Widget thuần dữ liệu, caller sở hữu inventory và cooldown, tái dùng `CooldownCountdownChip` hoặc `CircularProgressRing` cho phần cooldown.

## Yêu cầu kiểm thử
- [x] **Unit test**: Kiểm tra validate 1-5 ô, id duy nhất, count không âm, cooldown không âm; xác định trạng thái ô (sẵn sàng, hết hàng, cooldown, khoá).
- [x] **Widget test**: Tap ô sẵn sàng gọi `onSlotTap`; tap ô hết hàng gọi `onEmptySlotTap`; ô cooldown và ô khoá không gọi callback; badge hiển thị đúng; đếm ngược cooldown tự chuyển sang sẵn sàng; Reduced Motion; semantics đọc đúng tên và số lượng.
- [x] **Showcase test**: Tích hợp vào showcase có nút dùng booster và nạp thêm, cập nhật UI chính xác.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] Mỗi ô cô lập `RepaintBoundary`, giải phóng `AnimationController` (khởi tạo trong `initState` tránh deactivation lookup) và `Timer` khi unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
