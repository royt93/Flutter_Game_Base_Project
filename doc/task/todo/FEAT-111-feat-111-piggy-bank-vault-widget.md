---
id: FEAT-111
title: PiggyBankVault — Heo đất tích luỹ xu theo ván chơi kèm hiệu ứng đầy bình
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Cơ chế monetization kinh điển (Candy Crush, Royal Match): mỗi ván chơi thắng tích thêm xu vào heo đất, heo căng tròn rung nảy sẵn sàng đập.

## Đề xuất phạm vi
Widget PiggyBankVault hiển thị dung lượng hiện tại/tối đa, thanh tiến độ bụng heo, hiệu ứng rung nảy khi đạt mốc đầy và nút Đập heo / Mở khoá.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra tính toán phần trăm đầy bình và cờ isFull=true khi đạt dung lượng tối đa.
- [ ] **Widget test**: Render heo đất ở các mức 25%, 50%, 100%, kiểm tra mức 100% tự kích hoạt animation rung lắc mời gọi.
- [ ] **Integration test**: Tích xu vào heo đất sau ván chơi trên thiết bị thật, kiểm tra số nhảy và heo nảy vui nhộn.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Hiệu ứng nảy dùng Transform scale đơn giản, không tiêu tốn CPU khi không tương tác.
