---
id: FEAT-118
title: RadialActionMenu — Nút tròn FAB bung toả menu cánh cung nan quạt
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Nút hành động nổi ở góc màn hình (HUD hoặc góc app) bung toả các nút con (Share, Ranking, Sound, Help) giúp tiết kiệm diện tích và tăng tính sinh động.

## Đề xuất phạm vi
Widget RadialActionMenu nhận danh sách menu items, khi bấm nút chính sẽ bung các nút phụ theo hình vòng cung/nan quạt với độ nảy lò xo và góc toả tuỳ chỉnh.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán toạ độ sin/cos của từng nút con theo góc mở và bán kính vòng cung.
- [ ] **Widget test**: Tap mở menu, kiểm tra các nút con xuất hiện theo bán kính toả ra và chặn tap xuyên thấu ra ngoài bằng barrier.
- [ ] **Integration test**: Mở/đóng Radial menu ở góc màn hình GameDemo trên TECNO, kiểm tra thao tác một tay tiện lợi.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Dùng Transform.translate nhẹ nhàng cho từng nút, đóng menu khi tap ra vùng ngoài.
