---
id: ENH-101
title: Pulsing / Radar BadgeDot — Chấm thông báo nhịp tim & sóng lan toả
type: enhancement
priority: P2
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
BadgeDot hiện tại chỉ là chấm đỏ tĩnh, khó thu hút sự chú ý của người chơi vào các nút sự kiện, quà tặng chưa nhận.

## Đề xuất phạm vi
Nâng cấp BadgeDot với tuỳ chọn pulse: true (hiệu ứng nhịp đập tim scale 1.0->1.25) hoặc radar: true (vòng sóng hào quang mờ dần toả ra ngoài).

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra các cờ cấu hình và animation controller tự dừng khi mounted=false hoặc reducedMotion=true.
- [ ] **Widget test**: Render badge với radar=true, kiểm tra vòng sóng được vẽ mờ dần và scale tăng dần; tắt animation khi reducedMotion bật.
- [ ] **Integration test**: Hiển thị trên icon Shop và Quest trên thiết bị thật, kiểm tra hiệu ứng hút mắt nhìn và không lag.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Sử dụng RepaintBoundary cho vùng badge, chu kỳ animation nhẹ 1.5s/vòng.
