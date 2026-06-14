# 📋 Task Board — Neon Jewels

Bảng theo dõi công việc theo trạng thái. Mỗi task là 1 file `.md` được **di chuyển** giữa các thư mục:

```
doc/tasks/
├── todo/         # chờ làm
├── in-progress/  # đang code
└── done/         # đã xong (build pass + test pass)
```

## Quy ước file task

Tên file: `<wave>-<slug>.md` (vd: `w4-daily-reward.md`).

Frontmatter mỗi task:
```
---
id: w4-daily-reward
title: Daily Reward
wave: 4
status: todo | in-progress | done
owner: claude
---
```

## Wave 4 — ✅ DONE (song song 3 hướng)

| Nhóm | Task | Trạng thái | File |
|---|---|---|---|
| 1. Giữ chân | Daily Reward | ✅ done | `done/w4-daily-reward.md` |
| 1. Giữ chân | Lives / Energy | ✅ done | `done/w4-lives-energy.md` |
| 2. Game mode | Time Attack | ✅ done | `done/w4-mode-time-attack.md` |
| 2. Game mode | Drop Down | ✅ done | `done/w4-mode-drop-down.md` |
| 3. Obstacles | Ice / Chain / Stone | ✅ done | `done/w4-obstacles.md` |

Kết quả: 0 analyzer issue · 89 test pass · build APK debug OK.

## Wave 4.1 — ✅ DONE (verify máy thật + chiều sâu + i18n 22 ngôn ngữ + world)

| Bước | Nội dung | Trạng thái |
|---|---|---|
| #1 | Verify máy thật (3 mode + daily + mua mạng) | ✅ done |
| #2 | Drop Down replenish · mua đầy mạng · Time Attack +giây | ✅ done |
| #3 | Dịch đủ 22 ngôn ngữ key Wave 4 | ✅ done |
| #4 | World progression (5 thế giới + banner) | ✅ done |

Chi tiết: `done/w4.1-depth-i18n-worlds.md`. Kết quả: 0 analyzer issue · 98 test pass · build APK OK.

## Wave 5 — ✅ DONE 9/9 (cả 4 hướng + 4 tính năng, offline thuần)

| Nhóm | Task | Trạng thái | File |
|---|---|---|---|
| Meta | Achievement | ✅ done | `done/w5-achievements.md` |
| Meta | Win Streak | ✅ done | `done/w5-win-streak.md` |
| Meta | Lucky Wheel | ✅ done | `done/w5-lucky-wheel.md` |
| Meta | Pre-game Booster | ✅ done | `done/w5-pregame-boosters.md` |
| Hành trình | Tutorial lần đầu (+ vuốt) | ✅ done | `done/w5-tutorial.md` |
| Hành trình | World Map node-based (+ juice) | ✅ done | `done/w5-world-map.md` |
| Chiều sâu | Obstacle lan tỏa (chocolate) | ✅ done | `done/w5-spreading-obstacle.md` |
| Chiều sâu | Lucky / Mystery Gem | ✅ done | `done/w5-lucky-gem.md` |
| Cảm giác | Polish & Juice (slow-mo, particle) | ✅ done | `done/w5-polish-juice.md` |

Batch 1–4: tính năng. Batch 5: view-mode local (lưu DB khi user đổi style) + flutter_localizations + **test toàn diện**.

**Tổng kết Wave 5**: 0 analyzer issue · **128 unit/widget + 8 integration = 136 test pass** · verify thật iQOO Z9 Turbo (tất cả tính năng + 8 flow integration chạy trên máy).

## Wave 6 — ✅ DONE 3/3 (song song: Story + Endless/Theme + i18n)

| Nhóm | Task | Trạng thái | File |
|---|---|---|---|
| Hành trình | Story / Episode + NPC | ✅ done | `done/w6-story-episode.md` |
| Chiều sâu | Endless mode + Theme-per-world | ✅ done | `done/w6-endless-theme.md` |
| i18n | Dọn nợ (world_n + tên thế giới 22 ngôn ngữ) | ✅ done | `done/w6-i18n-polish.md` |

Kết quả: 0 analyzer issue · **140 unit/widget test pass** (+12 test Wave 6) · build APK debug OK.

> Nguồn chân lý tổng thể: [`../feat.md`](../feat.md). Bảng này chỉ theo dõi trạng thái chi tiết của Wave 4.
