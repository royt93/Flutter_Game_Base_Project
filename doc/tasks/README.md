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

## Bug fixes (đợt audit) — ✅ DONE

| Bug | Mô tả | Trạng thái |
|---|---|---|
| Nhạc nền không tắt khi ra background | Thiếu `WidgetsBindingObserver` → thêm lifecycle pause/resume nhạc (`main.dart` + `audio_manager.dart`) | ✅ done |
| Persistence tiền tệ | ~16 chỗ `setInt` fire-and-forget → bọc `unawaited`, gom xu qua `_setCoins` (clamp overflow int32), ghi guard-key trước khi phát thưởng (daily/wheel/achievement) chống exploit | ✅ done |

Kết quả: 0 analyzer issue · 140 test pass.

## Wave 7 — ✅ GIỮ CHÂN (meta ngoài lưới)

| Task | Mô tả | Trạng thái | File |
|---|---|---|---|
| Meta build "Đền Neon" | Tích Shard khi thắng → xây/nâng cấp công trình neon | ✅ done | `done/w7-meta-build.md` |
| Sự kiện theo mùa | Event tuần offline + theme + mốc thưởng | ✅ done | `done/w7-seasonal-event.md` |
| Battle Pass + nhiệm vụ ngày | Track thưởng theo cấp + 3 quest/ngày | ✅ done | `done/w7-battle-pass.md` |

## Wave 8 — 🟡 ĐỘC QUYỀN (signature)

| Task | Mô tả | Trạng thái | File |
|---|---|---|---|
| Trọng lực động / Mê cung | Bàn tự lật mỗi 5 lượt (MVP); 4 hướng + tường để dành | ✅ done | `done/w8-gravity-dynamic.md` |
| Boss neon theo lượt | Trùm có máu + điểm yếu + phản đòn hút lượt | ✅ done | `done/w8-boss-neon.md` |
| Chế độ Nhịp điệu | Ghép theo beat, groove meter (tận dụng 24 nốt) | 📋 todo | `todo/w8-rhythm-mode.md` |
| Co-op / Versus cục bộ | 2 người 1 máy, đua điểm / chung mục tiêu | 📋 todo | `todo/w8-coop-versus.md` |

Wave 7+8 (4 tính năng): 0 analyzer · **175 test pass** (+26) · build APK debug OK.

## Wave 8.1 — ✅ POLISH (UI + Audio, verify máy thật S24 Ultra)

| Việc | Mô tả | Trạng thái |
|---|---|---|
| Revamp Home | Bỏ 4 nút dọc → khu **THỬ THÁCH** (3 thẻ 1 hàng) + khu **PHẦN THƯỞNG** + hàng tiện ích nhỏ + chip xu top bar | ✅ done |
| Fix overlay action bar | `_GemSparkle` đè action bar → căn top + chừa 64px clearance | ✅ done |
| Fix tutorial nhầm chế độ | Tutorial lần-đầu hiện ở Boss/Gravity → thêm guard loại trừ chế độ phụ | ✅ done |
| Giai điệu nốt nhạc | `playMelodic`: **ngũ cung + màu gem = bậc âm + đổi tông theo khoá + hợp âm/arpeggio khi wombo** (thay chromatic đơn điệu). Hàm `noteIndexFor` thuần, test được | ✅ done |

Kết quả: 0 analyzer · **180 test pass** (+5 `test/w8_audio_test.dart`) · build + chạy thật S24 Ultra (SM-S928B): Home/Boss/Gravity/Temple/Season/Battle Pass/Endless OK, logcat sạch (không exception app).

> Nguồn chân lý tổng thể: [`../feat.md`](../feat.md).
