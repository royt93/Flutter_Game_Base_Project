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

## Yêu cầu kiểm thử
- [x] **Unit test**: Fill ratio clamp và `isFull` boundary; invalid capacity/amount.
- [x] **Widget test**: Amount at 25/50/100%, unlocked-full pulse, Reduced Motion no ticker, unlock/break actions.
- [x] **Showcase integration test**: Caller adds win-earned coins, unlocks and breaks vault.
- [x] **Physical-device smoke**: PiggyBank unlocked, filled to 100%, pulsed and broke back to 0 on Samsung S24 Ultra (SM-S928B); 60ms-scale sample showed pulse. TECNO disconnected earlier; no simulator used.
- [x] **Host validation**: root 2941/example 241 suites; both analyzers and quality gates pass.

## Hiệu năng & resource
- [x] Full-state animation uses bounded repeat `Transform.scale` and only creates ticker when full/unlocked/animations allowed; ticker stops when conditions clear and disposes on unmount.
- [x] S24 Ultra (SM-S928B) profile build, LiveFrameGraph rolling 100-frame window while PiggyBank was full and pulsing: jank 0, no slow/jank bars, latest-frame estimate 131 FPS. This is a short window sample, not a sustained benchmark or 60 FPS guarantee.
