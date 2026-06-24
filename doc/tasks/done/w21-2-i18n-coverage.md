---
id: w21-2-i18n-coverage
title: i18n coverage — Dịch 20 ngôn ngữ key còn thiếu W5/7/8
wave: 21
phase: 2
status: done
owner: claude
---

✅ **DONE 2026-06-22** — Phát hiện và fix bug thật: `_w20ByLang` dùng key ngắn (`'es'`, `'fr'`...)
thay vì full locale code (`'es_ES'`, `'fr_FR'`...) → 20 ngôn ngữ không nhận key Wave 20
(Zen, Ghost, Progression Tree, Challenge Card, world_name_9/10). Fix: Python script
thay 20 key trong block `_w20ByLang`. **633 test pass** · 0 analyzer.

# Phase 2 — i18n Coverage (blocker phát hành đa ngôn ngữ)

## Vấn đề

Audit Wave 8.9 phát hiện: **EN + VI đầy đủ, 20 ngôn ngữ còn lại ~49-51% key hiện tiếng Anh**.

Key chưa dịch (Wave 5/7/8): achievements, win_streak, ach_desc_*, guide_rhythm/boss/versus,
battle-pass tiers, season-league, side-mode records, puzzle, progression-tree, challenge-card,
zen, ghost, daily-mutators.

Test hiện tại (`app_translations_test.dart`) chỉ kiểm key đủ (qua fallback), KHÔNG kiểm value
đã dịch → đang ru ngủ. Threshold hiện `≥79%` value differ from English per language.

## Scope (ước tính ~2,400 chuỗi)

Chia thành 4 batch để dịch song song (4 agent):
- **Batch A** — Achievements + Win Streak + Ach descriptions (ach_title_*, ach_desc_*)
- **Batch B** — Guide sections (rhythm, boss, versus, survival, labyrinth, daily)
- **Batch C** — Battle Pass + Season League + Side Mode Records + Puzzle
- **Batch D** — Progression Tree + Challenge Card + Zen + Ghost + Daily Mutators + W20 keys

## Cách làm

1. Thêm map `_w21ByLang` mới trong `app_translations.dart` (pattern từ `_w20ByLang`).
2. Merge vào `keys` getter: `...?_w21ByLang[e.key]`.
3. Nâng threshold test từ `≥79%` → `≥85%` (tăng dần theo mỗi batch xong).
4. Chạy `flutter test test/app_translations_test.dart` sau mỗi batch.

## Ngôn ngữ target (20 ngôn ngữ)
es, fr, de, pt, ru, zh, ja, ko, it, id, th, hi, ar, tr, nl, pl, fil, ms, uk, bn

## Lưu ý
- Giữ `@n`/`@t` placeholder nguyên vẹn.
- Universal gaming terms (COMBO, PERFECT, ZEN, GHOST) giữ tiếng Anh — không dịch.
- Test phải chạy xanh sau mỗi batch trước khi commit.
- Liên quan: [[i18n-extra-merge]], [[i18n-coverage-gap]].
