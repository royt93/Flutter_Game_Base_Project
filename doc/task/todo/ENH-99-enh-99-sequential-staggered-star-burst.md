---
id: ENH-99
title: Sequential Staggered StarBurst cho ProgressBarStars và VictoryCard
type: enhancement
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Sao trong ProgressBarStars và VictoryCard hiện chỉ hiện tĩnh hoặc pop cùng lúc, thiếu nhịp điệu hào hứng khi tổng kết sao màn chơi.

## Đề xuất phạm vi
Hỗ trợ animation staggered: sao 1 nổ tại 0ms, sao 2 tại 250ms, sao 3 tại 500ms kèm độ nảy squash-stretch riêng từng sao và callback onStarPopped(index).

## Yêu cầu kiểm thử (Bắt buộc theo chuẩn đối tác)
- [ ] **Unit test**: Kiểm tra thứ tự kích hoạt callback onStarPopped theo đúng mốc thời gian.
- [ ] **Widget test**: Pump theo từng khoảng 250ms, kiểm tra từng ngôi sao đổi trạng thái từ rỗng sang đầy kèm hiệu ứng scale.
- [ ] **Integration test**: Mở VictoryCard 3 sao trên thiết bị thật, nghe nhịp rung và thấy hiệu ứng nổ tuần tự rõ ràng.

## Yêu cầu hiệu năng & Animation
- [ ] **60 FPS & Resource cleanup**: Mỗi sao chia sẻ chung 1 controller hoặc dùng Interval staggered trên 1 AnimationController duy nhất.
