---
id: FEAT-124
title: TieredRewardChest — Rương báu đa tầng nâng cấp Wood/Silver/Gold/Diamond
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & Live-Ops Expansion (Wave 6)
---

## Vì sao cần
Cơ chế rương nâng cấp nhiều bậc (mỗi lần ghép combo hoặc tích điểm thì rương từ Gỗ nâng lên Bạc, Vàng, Kim Cương) mang lại cảm giác phấn khích và thôi thúc người chơi hoàn thành màn xuất sắc hơn.

## Đề xuất phạm vi
Widget `TieredRewardChest` nhận danh sách các tier rương, hiển thị hoạt họa rung lắc nâng cấp (shake + squash-stretch) khi tier tăng lên, và mở rương bung phần thưởng từng tầng kèm tia sáng theo màu tier.

## Yêu cầu kiểm thử
- [ ] **Unit test**: Kiểm tra logic chuyển tier, clamp tier trong khoảng hợp lệ và xác định phần thưởng theo tier hiện tại.
- [ ] **Widget test**: Kiểm tra thay đổi tier kích hoạt hoạt họa nâng cấp, bấm mở rương gọi callback `onOpen` và bung quà; Reduced Motion bỏ qua hiệu ứng rung nảy.
- [ ] **Showcase test**: Demo thanh tăng tier và mở rương trong showcase, hiển thị đúng tier và quà tương ứng.
- [ ] **Physical integration**: Kiểm tra tương tác trên thiết bị thật TECNO KJ7 / physical device, không dùng simulator.

## Hiệu năng & Animation
- [ ] Tái sử dụng CustomPainter hoặc composable widgets có `RepaintBoundary`, giải phóng `AnimationController` khi đóng.
- [ ] Sustained 60 FPS benchmark: đo theo quy chuẩn định sẵn nếu cần.
