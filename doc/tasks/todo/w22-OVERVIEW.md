---
id: w22-overview
title: Wave 22 — Polish & Onboarding & Đóng nợ
wave: 22
status: todo
owner: claude
created: 2026-06-26
---

# 🌊 Wave 22 — Polish · Onboarding · Đóng nợ

Sau Wave 21 (Boss/Rhythm/Rush/Leaderboard). Wave 22 nghiêng về **đánh bóng cảm giác**,
**onboarding người mới**, và **đóng các mảnh dang dở** — phần lớn là *augment* hệ thống
SẴN CÓ (rủi ro thấp), không xây mới từ đầu.

| Phase | Task | File plan | Ưu tiên | Quy mô | Ghi chú quan trọng |
|---|---|---|---|---|---|
| 1 | **Game Feel / Juice** | `w22-1-game-feel-juice.md` | 🔴 Cao | S–TB | Shake/slow-mo/combo-text/particle ĐÃ CÓ — chỉ thêm **trail gem rơi** + **visual gem hiếm** + tinh chỉnh threshold |
| 2 | **World Map Events** | `w21-5-world-map-events.md` (đã có) | 🟡 TB | TB | Dùng plan w21-5 (chest + mini-boss + avatar). KHÔNG viết lại |
| 3 | **First-launch Onboarding** | `w22-3-onboarding.md` | 🟡 TB | S–TB | Tutorial HOW TO PLAY L1 ĐÃ CÓ — Wave 22 thêm **tour Home** (giới thiệu side-mode/shop/LB) 1 lần |
| 4 | **Đóng nợ: Daily LB score + i18n tên TG** | `w22-4-debt-daily-i18n.md` | 🟢 Thấp | S | Cả 2 đều nhỏ; i18n tên TG chỉ cần wire `.tr` (key đã có sẵn 22 ngôn ngữ) |

**Thứ tự đề xuất**: 4 (đóng nợ nhanh, thắng dễ) → 1 (juice, wow) → 3 (onboarding) → 2 (World Map).

## Nguyên tắc chung
- Tất cả side-mode/visual phải tôn trọng `isSideMode` + không đụng logic match-3 core.
- Mọi key mới phải thêm vào `resetProgress()` (chống re-claim / badge stale) — xem [[reset-permanent-controllers]].
- Juice phải có thể TẮT hoặc giảm (accessibility: tránh motion sickness) — cân nhắc gắn cờ Settings.
- Liên quan: [[side-mode-isolation]], [[balance-economy-principles]].
