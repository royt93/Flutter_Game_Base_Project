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

## Yêu cầu kiểm thử
- [x] **Widget test**: Callback thứ tự 0/250/500ms, Reduced Motion không chờ stagger, downgrade progress hủy timer đang chờ, unmount hủy timer; VictoryCardTemplate có slot sao tùy chọn.
- [x] **TECNO UI check**: TECNO KJ7 (115333744A005844) showed three VictoryCard stars, verified sequential callbacks, replayed burst and confirmed visible star order. No simulator.
- [ ] Host validation: historical full suite counts above are stale; rerun before closing task.

## Yêu cầu hiệu năng & Animation
- [x] Timer được hủy khi progress giảm hoặc widget dispose; star controllers được dispose. Performance frame-time chưa được benchmark riêng cho widget này.
