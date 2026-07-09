---
id: w28-OVERVIEW
title: "Wave 28 — Audit tính năng cũ + 4 hướng đề xuất"
wave: 28
status: todo
owner: claude
---

# Wave 28 — Tổng quan

Nguồn: audit kỹ 12+ side mode + 12 hệ thống meta-progression + core mechanics/i18n/tech-debt
(3 Explore agent, đọc code thật, 2026-07-09). Chi tiết đầy đủ: xem `feat.md` mục
"Wave 28 — Audit tính năng cũ (2026-07-09)".

4 hướng dưới đây **độc lập nhau** — chọn 1 hoặc vài hướng để chuyển `in-progress`,
không bắt buộc làm hết cùng lúc.

| # | Task | File | Trạng thái |
|---|---|---|---|
| 1 | Enhance mode yếu + mechanic phí (Versus PvP thật, Zen/ColorRush/Puzzle thêm depth, dùng thêm Flow/Conveyor/Portal) | `w28-1-enhance-weak-modes.md` | 📋 todo |
| 2 | Social/Viral (share kết quả, invite, rate app) | `w28-2-social-viral.md` | 📋 todo |
| 3 | Cứu "dead feature" risk (Piggy/Collection/Progression Tree/Lucky Wheel) | `w28-3-dead-feature-rescue.md` | 📋 todo |
| 4 | Tính năng match-3 hoàn toàn mới (Boss Rush luân chuyển / Versus PvP async qua Ghost Mode) | `w28-4-new-mode.md` | 📋 todo |
| 5 | Weekly Rotating World Event (buff/debuff toàn cầu tuần) | `w28-5-weekly-world-event.md` | 📋 todo |
| 6 | Gem Fusion/Crafting (ghép 2 gem đặc biệt cùng loại) | `w28-6-gem-fusion.md` | 📋 todo |
| 7 | Neon Companion (Pet cosmetic, lớp thu thập mới) | `w28-7-neon-companion.md` | 📋 todo |
| 8 | Local Split-Screen Realtime Versus | `w28-8-split-screen-versus.md` | 📋 todo |

**Đề xuất của agent (không ràng buộc)**: #1 và #5 trước — code nền có sẵn (Flow
engine, Versus skeleton, Daily mutator pattern), effort thấp, rủi ro thấp. #6/#8
đụng core gesture/Flame instance — rủi ro cao nhất, nên làm sau khi #1-5-7 ổn.
