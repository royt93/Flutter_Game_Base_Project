---
id: w23-overview
title: Wave 23 — Trả nợ i18n + hoàn thiện + nội dung mới
wave: 23
status: todo
owner: claude
created: 2026-06-26
---

# 🌊 Wave 23 — i18n debt · hoàn thiện · nội dung

Sau Wave 22 (Leaderboard, Onboarding, Game Feel, World Map chest/mini-boss). Wave 23
ưu tiên **đóng nợ i18n** do W21.6+W22 tạo, **hoàn thiện** các mục defer, rồi **nội dung mới**.

| Phase | Task | File | Ưu tiên | Quy mô | Ghi chú |
|---|---|---|---|---|---|
| 1 | ✅ **i18n localize W22** (done 2026-06-26) | `w23-1-i18n-w22.md` | 🔴 Cao | TB | DONE: `_w22ByLang` 20 ngôn ngữ × 23 key, gỡ exclusion; test ≥80% pass |
| 2 | **Mini-boss hoàn thiện** | `w23-2-miniboss-complete.md` | 🟡 TB | TB | Persist `miniBossCleared(world)` + thưởng khi thắng + (tùy) attack pattern Meteor/Shuffle (defer từ w21-3) |
| 3 | ✅ **Avatar walking animation** (done 2026-06-26) | (trong w21-5) | 🟢 Thấp | S | DONE: TweenAnimationBuilder "đi" từ node trước→hiện tại + bob, re-run khi current đổi |
| 4 | 🟡 **Nội dung mới** (skin/theme + Daily Quest done 2026-06-26) | `w23-4-content.md` | 🟢 Thấp | TB+ | DONE: +3 gem skin + 3 board theme (coin-sink 1000-1500); Daily Quest mở rộng (pool 9→14 tier + thưởng hoàn-thành-cả-bộ 1 lần/ngày anti-farm). Clan/Friends offline vẫn để sau |

**Thứ tự đề xuất**: 1 (đóng nợ test) → 2 → 3 → 4.

## Bối cảnh nợ i18n (quan trọng)
W21.6 + W22 thêm ~23 key UI chỉ có **en + vi**; 20 ngôn ngữ còn lại fallback English. Để giữ
`flutter test` xanh, các key này **tạm loại khỏi ratio** trong `test/app_translations_test.dart`
(`universalKeys`). Phase 1 phải: (a) thêm `_w22ByLang` dịch 20 ngôn ngữ (theo [[i18n-extra-merge]]),
(b) **gỡ** các key W22 khỏi `universalKeys`, (c) test ≥80% phải vẫn pass.

## Nguyên tắc
- Mọi key mới → vẫn theo convention `_extraEn/_extraVi` + `_wXXByLang` (xem [[i18n-coverage-gap]]).
- Mini-boss/avatar tôn trọng [[side-mode-isolation]]; key mới → `resetProgress` nếu cần.
- Liên quan: [[balance-economy-principles]], [[reset-permanent-controllers]].
