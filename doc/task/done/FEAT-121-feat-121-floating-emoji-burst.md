---
id: FEAT-121
title: FloatingEmojiBurst — Emoji tương tác thả tim/cười bay lượn từ góc màn hình
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Người chơi rất thích thả tim, thả biểu cảm vỗ tay/cười vui khi bạn bè ghi điểm hoặc trong phòng chơi chung (tương tự Monopoly Go / TikTok live).

## Đề xuất phạm vi
Widget FloatingEmojiBurst nhận trigger emoji (tim, cười, vỗ tay...), sinh ra các biểu tượng bay bổng zíc zắc từ góc màn hình lên trên rồi mờ dần biến mất.

## Kiểm thử
- [x] **Unit/widget tests**: deterministic sine-wave offsets, exact opacity endpoints, config validation, five-item auto-cleanup, 20-item cap drops new requests, Reduced Motion skip.
- [x] **Showcase test**: five heart triggers render and auto-clean after bounded animation duration.
- [x] **Physical integration**: TECNO KJ7 (115333744A005844) triggered five heart emojis and confirmed automatic completion/cleanup. No simulator used.
- [ ] **Samsung S24 Ultra profile**: not measured; optional follow-up, no sustained FPS claim.
- [x] **Host validation**: root 2985/example 250 suites; analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] Shared ticker; max 20 active; removes completed particles and stops ticker when empty; disposal cleanup.
- [ ] Sustained 60 FPS benchmark not measured.
