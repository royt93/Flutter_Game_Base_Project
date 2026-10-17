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
- [ ] **Unit test**: Kiểm tra tính toán % tiến độ, trạng thái `isReadyToOpen`, validate `targetStars > 0` và `currentStars >= 0`.
- [ ] **Widget test**: Khi đủ sao hiển thị nhãn "Open!" và gọi `onOpenChestTap` khi bấm; khi chưa đủ gọi `onInfoTap`; Reduced Motion tắt hiệu ứng golden pulse.
- [ ] **Showcase test**: Tích hợp cụm Star Chest vào showcase có nút cộng sao và mở rương, cập nhật UI chính xác.
- [ ] **Physical integration**: Kiểm tra hiển thị và phản hồi tap trên thiết bị vật lý thật (Pixel 7 Pro), không dùng simulator.

## Hiệu năng & Animation
- [ ] Golden pulse điều khiển bởi `AnimationController` chạy lặp khi rương sẵn sàng, tự động dừng khi unmount hoặc khi sao chưa đầy.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
