---
id: FEAT-122
title: WheelPointerClicker — Kim chỉ vòng quay nảy rung vật lý theo từng nan quạt
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
WheelSpinner hiện tại có kim chỉ đứng yên khi vòng quay quay. Vòng quay chuyên nghiệp luôn có chiếc kim nảy lắc (tick bounce) theo từng nan quạt đi qua kèm âm thanh cạch cạch.

## Đề xuất phạm vi
Mở rộng WheelSpinner thêm widget con WheelPointerClicker tự động tính toán góc tiếp xúc của các nan quạt, xoay góc kim nảy nhẹ mỗi khi nan quạt đi qua và phát haptic/sfx tick.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra góc nghiêng của kim dựa trên vận tốc quay của bánh xe và số lượng nan quạt.
- [ ] **Widget test**: Quay bánh xe, kiểm tra kim chỉ đổi góc quay dao động tuần hoàn và gọi onTick mỗi khi vượt qua 1 nan quạt.
- [ ] **Integration test**: Quay vòng quay may mắn trên thiết bị thật, quan sát kim gõ nhịp nảy chân thực kèm âm thanh cạch cạch.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Tính toán góc quay trực tiếp theo góc xoay bánh xe, không dùng timer riêng.
