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
- [ ] **TECNO UI check**: Chưa xác minh VictoryCardTemplate 3-sao trên thiết bị thật.
- [x] **Host validation**: root 2881 tests, example 230 tests, analyzer, API/accessibility/performance/SBOM/license/deprecation gates pass.

## Yêu cầu hiệu năng & Animation
- [x] Timer được hủy khi progress giảm hoặc widget dispose; star controllers được dispose. Performance frame-time chưa được benchmark riêng cho widget này.
