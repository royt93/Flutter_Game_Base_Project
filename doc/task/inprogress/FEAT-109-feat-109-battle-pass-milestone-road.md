---
id: FEAT-109
title: BattlePassRoad / MilestoneTrack — Đường ray mốc phần thưởng Free & VIP
type: feature
priority: P0
effort: L
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Tính năng giữ chân người chơi quan trọng nhất của casual/live-ops game. Hiển thị chuỗi mốc tiến độ mùa, quà Free và quà VIP.

## Đề xuất phạm vi
Widget BattlePassRoad nhận danh sách MilestoneItem, vẽ đường ray tiến độ nối giữa các mốc, đánh dấu trạng thái locked/claimable/claimed và hỗ trợ cuộn tới mốc hiện tại.

## Kiểm thử
- [x] **Unit test**: Local segment ratio/clamping, current milestone, per-track locked/claimable/claimed rules, model and ordered-ID validation.
- [x] **Widget test**: 10 milestones lazily built, current milestone 5, claim callback routes stable ID/track, invalid ordering rejected.
- [x] **Showcase test**: Free/VIP claims update caller-owned state through RewardTransactionPipeline and wallet deltas.
- [x] **TECNO integration smoke**: 30-tier road scrolled through tier 30 on TECNO KJ7.
- [x] **Host validation**: root 2932/example 239 suites and all quality gates passed; final claimed-status regression assertion plus package/example analyzers and focused widget tests passed.

## Hiệu năng & Animation
- [x] ListView.builder virtualizes milestone rows; each row paints one short rail segment.
- [ ] 60 FPS benchmark: TECNO scroll smoke passed; sustained frame-time benchmark not measured.
