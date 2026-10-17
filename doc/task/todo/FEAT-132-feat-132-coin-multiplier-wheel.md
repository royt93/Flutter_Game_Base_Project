---
id: FEAT-132
title: CoinMultiplierWheel — Vòng quay kim lắc nhân thưởng cuối màn (x2, x3, x5, x10)
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Retention Expansion (Wave 8)
---

## Vì sao cần
Cơ chế kim lắc qua lại trên thanh nan quạt nhân tiền thưởng sau khi thắng màn (Victory Multiplier Minigame) là cơ chế xem quảng cáo hoặc minigame quen thuộc trong các game hyper-casual và puzzle (người chơi bấm dừng đúng lúc để trúng x5 hoặc x10).

## Đề xuất phạm vi
Widget `CoinMultiplierWheel` hiển thị:
- Cánh cung nan quạt hoặc thước đo hình bán nguyệt chia các ô nhân thưởng (x2, x3, x5, x10).
- Kim chỉ dao động qua lại theo hàm sin mượt mà (`AnimationController(duration: 1200ms)` lặp lại).
- Khi chạm nút hoặc chạm vào widget: kim dừng lại ở ô hiện tại, kích hoạt hiệu ứng nảy và gọi callback `onStopped(int multiplier)` truyền giá trị nhân trúng.
- Hỗ trợ Reduced Motion: kim di chuyển bước chậm hoặc người chơi tự bấm chọn ô trực tiếp.
- Widget thuần trình bày: caller sở hữu số xu gốc và logic cộng tiền qua `EconomyWallet`.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra tính toán góc dừng kim tương ứng với multiplier trúng thưởng, validate danh sách multipliers hợp lệ (ít nhất 2 ô, multiplier >= 1).
- [ ] **Widget test**: Bấm nút dừng kim khóa chuyển động, gọi callback `onStopped` đúng giá trị; Reduced Motion; semantics đọc đúng các mốc nhân thưởng.
- [ ] **Showcase test**: Tích hợp vào showcase với nút bắt đầu lắc và dừng kim, cập nhật số tiền nhân được chính xác.
- [ ] **Physical integration**: Kiểm tra hiển thị và tap trên thiết bị vật lý thật (Pixel 7 Pro), không dùng simulator.

## Hiệu năng & Animation
- [ ] Kim dao động vẽ trong `RepaintBoundary`, giải phóng `AnimationController` khi unmount hoặc dừng kim.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
