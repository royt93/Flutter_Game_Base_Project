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
- [ ] **TECNO smoke**: pending; isolated Java17 build succeeded, but ADB disconnected before Flutter test began (`Unable to start the app on the device` / device not found). No simulator used.
- [x] **Host validation**: root 2941/example 241 suites; both analyzers and quality gates pass.

## Hiệu năng & resource
- [x] Full-state animation uses bounded repeat `Transform.scale` and only creates ticker when full/unlocked/animations allowed; ticker stops when conditions clear and disposes on unmount.
- [ ] 60 FPS benchmark not measured.
