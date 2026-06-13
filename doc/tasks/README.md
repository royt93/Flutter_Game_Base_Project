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

> Nguồn chân lý tổng thể: [`../feat.md`](../feat.md). Bảng này chỉ theo dõi trạng thái chi tiết của Wave 4.
