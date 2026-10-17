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
- [x] **Unit test**: Kiểm tra tính toán góc dao động kim `multiplierNeedleAngleAtProgress`, ánh xạ tiến độ sang sector `multiplierIndexAtNormalizedProgress`, validate danh sách multipliers hợp lệ (ít nhất 2 ô, multiplier >= 1), radius dương và duration.
- [x] **Widget test**: Bấm nút dừng kim khóa chuyển động, gọi callback `onStopped` đúng giá trị; controller `start`/`stop`/`reset`; Reduced Motion dừng kim ở giữa; semantics đọc đúng các mốc nhân thưởng và kết quả dừng.
- [x] **Showcase test**: Tích hợp vào showcase với nút bắt đầu lắc và dừng kim, cập nhật số tiền nhân được chính xác.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] Kim dao động và cánh cung vẽ trong `RepaintBoundary`, giải phóng `AnimationController` khi unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
