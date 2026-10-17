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
- [x] **Unit test**: Kiểm tra thứ tự tier, màu/name, size validation và reward widget theo tier hiện tại.
- [x] **Widget test**: Nâng tier phát bounce; mở rương gọi `onOpen` và hiện quà tương ứng; Reduced Motion bỏ qua hiệu ứng.
- [x] **Showcase test**: Nâng tier Wood → Silver, mở rương và xác nhận reward Silver.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] Rương vẽ bằng `CustomPainter` trong `RepaintBoundary`; controller dispose khi unmount.
- [ ] Sustained 60 FPS benchmark: chưa đo; không tuyên bố đạt 60 FPS.
