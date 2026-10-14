---
id: FEAT-120
title: StackedAvatarGroup — Cụm avatar bạn bè/clan xếp chồng chéo kèm số dư +N
type: feature
priority: P2
effort: S
source: Scrum Master Epic: Casual Game & App Master Suite (Partner Quality Assurance)
---

## Vì sao cần
Trong game casual có yếu tố mạng xã hội (bạn bè đang online, thành viên bang hội, người cùng chơi ván đấu), hiển thị cụm avatar xếp chồng là tiêu chuẩn ngành.

## Đề xuất phạm vi
Widget StackedAvatarGroup nhận danh sách avatar URL/Widget, hiển thị tối đa N avatar xếp đè lên nhau với viền trắng bo tròn và badge tròn số lượng dư (ví dụ: +5) ở cuối.

## Kiểm thử
- [x] **Unit/widget tests**: cap/overflow math, invalid size/overlap/max, 6 avatars with max=3 shows +3, no badge when all fit, avatar/overflow callbacks, semantics, RTL mirroring.
- [x] **Showcase test**: capped group renders +3; overflow tap updates caller state.
- [x] **Physical integration**: Samsung S24 Ultra (SM-S928B) rendered +3 badge, badge hit-testable, tap fired callback once. No simulator.
- [x] **Host validation**: root 2979/example 249 suites; analyzers and all quality gates pass.

## Hiệu năng & Animation
- [x] Stack with PositionedDirectional, no controller/ticker, zero animation overhead.
- [ ] Network avatar path (`StackedAvatarItem.url`) not exercised by tests; only widget path covered.
- [ ] Sustained 60 FPS benchmark not measured.
