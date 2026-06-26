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
| 1 | **i18n localize W22** | `w23-1-i18n-w22.md` | 🔴 Cao | TB | ~23 key (chest/tour/reduce_motion/lb) hiện chỉ en+vi → dịch 20 ngôn ngữ qua `_w22ByLang`, bỏ khỏi exclusion trong app_translations_test |
| 2 | **Mini-boss hoàn thiện** | `w23-2-miniboss-complete.md` | 🟡 TB | TB | Persist `miniBossCleared(world)` + thưởng khi thắng + (tùy) attack pattern Meteor/Shuffle (defer từ w21-3) |
| 3 | **Avatar walking animation** | (trong w21-5) | 🟢 Thấp | S | Hiện avatar tĩnh ở node hiện tại → AnimatedPositioned "đi" mượt khi mở map / sau khi thắng |
| 4 | **Nội dung mới** | `w23-4-content.md` | 🟢 Thấp | TB+ | Gem skin/board theme mới (coin-sink), hoặc Daily Quest mở rộng, hoặc Clan/Friends offline (idea pool) |

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
