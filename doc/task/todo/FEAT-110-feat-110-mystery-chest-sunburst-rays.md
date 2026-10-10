---
id: FEAT-110
title: MysteryChest & Sunburst God Rays — Mở rương báu bật nắp & hào quang quay
type: feature
priority: P0
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Khoảnh khắc mở rương báu là trải nghiệm cảm xúc cao nhất của game casual; cần rương rung lắc, nắp bật mở kèm tia hào quang xoay tròn phía sau.

## Đề xuất phạm vi
Widget MysteryChestOpening với trạng thái idle (thở nhẹ) -> shake (rung lắc hồi hộp) -> burstOpen (nắp bật) -> reveal kèm SunburstGodRays xoay tròn phía sau.

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra state machine chuyển đổi tuần tự: idle -> shaking -> opened -> revealed.
- [ ] **Widget test**: Tap vào rương đang lắc, kiểm tra rương mở nắp và sunburst rays bắt đầu quay tròn sau lưng rương.
- [ ] **Integration test**: Mở rương báu nhận thưởng trên TECNO, kiểm tra độ mượt của tia sáng quay 60fps.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Tia sáng mặt trời vẽ bằng path hình nón xoay góc toán học đơn giản, không dùng texture nặng.
