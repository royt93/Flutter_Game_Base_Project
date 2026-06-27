---
id: w24-overview
title: Wave 24 — Device-verify batch + đóng nợ nhỏ + content mới
wave: 24
status: todo
owner: claude
created: 2026-06-27
---

# 🌊 Wave 24 — Device-verify · đóng nợ · content

Phiên W22-23 build nhiều feature **chỉ verify bằng test (không device)**. Wave 24 gom các
việc **cần device** lại một mẻ (làm khi máy ổn định), đóng vài nợ nhỏ, rồi content mới.

| Phase | Task | File | Ưu tiên | Cần device? | Ghi chú |
|---|---|---|---|---|---|
| 1 | **Device-verify batch** | `w24-1-device-verify.md` | 🔴 Cao | ✅ Có | Verify + tinh chỉnh các thứ chưa thấy mắt: gem trail (FPS), juice combo, chest/mini-boss node, avatar walk, clan/leaderboard/quest-bonus UI; + checklist B3 split-screen, B4 perf/resume |
| 2 | **2B engine: boss shuffle/meteor** | `w23-2-miniboss-complete.md` | 🟡 TB | ✅ Có | Wire hiệu ứng: game react `bossAttackSignal` → `_doShuffle` (shuffle, phase 2) / clear-cell (meteor); selector `bossAttackPatternFor` đã có (W23.2B) |
| 3 | **Localize key W23 còn lại** | `w24-3-i18n-w23.md` | 🟢 Thấp | ❌ | 3 key en+vi (`quest_bonus_title`, `clan_title`, `clan_goal`) → dịch 20 ngôn ngữ (thêm vào `_w22ByLang` hoặc `_w24ByLang`). Hiện ratio vẫn ≥80% nhưng nên đóng cho sạch |
| 4 | **Clan content sâu hơn** | `w24-4-clan-plus.md` | 🟢 Thấp | ❌ | Clan vs Clan (giải tuần giữa nhiều clan bot), chat-emote tất định, hoặc đóng góp từ side-mode (hiện chỉ campaign). Pure offline + testable |

**Thứ tự đề xuất**: 3 (sạch i18n, không device) → 4 (content, không device) → 1+2 (gom khi có device).

## Lý do gom device-verify
Nhiều feature W22-23 (gem trail, juice, các node WorldMap, avatar walk, UI clan/leaderboard/
quest-bonus) **chưa nhìn bằng mắt** — chỉ test logic + widget mount. Làm 1 mẻ verify trên
device (Redmi/Vivo/Samsung) sẽ rẻ + nhất quán hơn rải rác. Kèm B3 split-screen, B4 perf/resume
(RELEASE_CHECKLIST chưa tick).

## Nguyên tắc (NHẮC)
- 🚫 **KHÔNG commit** — chỉ code + test, user tự commit (xem [[code-on-main-only]]).
- Mọi feature offline + key mới theo convention i18n; key persist → `resetProgress`.
- Liên quan: [[side-mode-isolation]], [[balance-economy-principles]].
