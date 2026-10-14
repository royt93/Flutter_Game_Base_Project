---
id: FEAT-118
title: RadialActionMenu — Nút tròn FAB bung toả menu cánh cung nan quạt
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Nút hành động nổi ở góc màn hình (HUD hoặc góc app) bung toả các nút con (Share, Ranking, Sound, Help) giúp tiết kiệm diện tích và tăng tính sinh động.

## Đề xuất phạm vi
Widget RadialActionMenu nhận danh sách menu items, khi bấm nút chính sẽ bung các nút phụ theo hình vòng cung/nan quạt với độ nảy lò xo và góc toả tuỳ chỉnh.

## Kiểm thử
- [x] **Unit test**: sin/cos radial offset, radius, arc bounds and invalid values.
- [x] **Widget test**: open state, barrier blocks taps through, action callback closes menu, Reduced Motion instant open.
- [x] **Showcase test**: primary menu opens; action callback updates caller state.
- [x] **Physical smoke**: Samsung S24 Ultra (SM-S928B) tapped primary, selected Share, verified outside barrier consumed tap and closed menu; no simulator.
- [x] **Host validation**: root 2967/example 247 suites; analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] Child buttons use positioned offsets with scale animation and controller disposes on unmount; outside barrier closes menu.
- [ ] Sustained 60 FPS benchmark not measured.
