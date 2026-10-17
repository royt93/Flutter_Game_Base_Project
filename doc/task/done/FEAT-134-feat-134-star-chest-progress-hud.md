---
id: FEAT-134
title: StarChestProgressHud — Cụm HUD tích luỹ sao mở rương ngôi sao (Star Chest)
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Retention Expansion (Wave 8)
---

## Vì sao cần
Cơ chế "Star Chest" (thu thập đủ 20 hoặc 30 ngôi sao từ việc vượt màn để mở rương báu đặc biệt) là động lực to lớn thúc đẩy người chơi chơi lại các màn cũ để đạt tối đa 3 sao.

## Đề xuất phạm vi
Widget `StarChestProgressHud` hiển thị:
- Icon rương ngôi sao kèm badge sao vàng đính ở góc.
- Thanh tiến độ thu thập sao (`currentStars`, `targetStars`).
- Khi đủ sao (`currentStars >= targetStars`): rương chuyển sang trạng thái "Sẵn sàng mở" với hiệu ứng nhịp đập vàng hào quang (golden pulse) và nhãn "Open!".
- Callback `onOpenChestTap` khi rương đã đầy; khi chưa đủ sao tap vào hiển thị tooltip hoặc gọi `onInfoTap`.
- Widget thuần dữ liệu: caller sở hữu số sao tích luỹ và logic trả thưởng khi mở.

## Yêu cầu kiểm thử
- [x] **Unit test**: Kiểm tra `starChestProgressFraction`, kẹp 0.0..1.0, validate `targetStars > 0`, `currentStars >= 0` và chiều cao dương.
- [x] **Widget test**: Khi đủ sao hiển thị nhãn "Open!" và gọi `onOpenChestTap` khi bấm; khi chưa đủ hiển thị số sao và gọi `onInfoTap`; Reduced Motion tắt hiệu ứng golden pulse; semantics đọc rõ tiến độ sao và trạng thái sẵn sàng mở.
- [x] **Showcase test**: Tích hợp cụm Star Chest vào showcase có nút cộng sao và mở rương, cập nhật UI chính xác.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] Golden pulse điều khiển bởi `AnimationController` chạy lặp khi rương sẵn sàng, tự động dừng khi unmount hoặc khi sao chưa đầy; vẽ trong `RepaintBoundary`.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
