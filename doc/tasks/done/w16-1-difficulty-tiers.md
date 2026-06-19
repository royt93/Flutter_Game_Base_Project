---
id: w16-1-difficulty-tiers
title: Tier độ khó + Sawtooth + nhãn hiển thị
wave: 16
phase: 1
status: done
owner: claude
---

# Phase 1 — Difficulty tiers (70/25/5) + Sawtooth pacing + badge

Theo infographic Match-3: mỗi màn gắn nhãn độ khó cụ thể; phân bố ~Normal 70% /
Hard 25% / Super-Hard 5%; nhịp RĂNG CƯA (sau màn Super-Hard → 2-3 màn dễ nghỉ).

## Thiết kế
- `enum LevelTier { normal, hard, superHard }` + `levelTier(index)` TẤT ĐỊNH cho
  150 màn, đạt xấp xỉ 70/25/5. Super-Hard ở vài màn đỉnh (cuối thế giới / mốc),
  Hard rải đều, còn lại Normal.
- **Sawtooth**: màn ngay SAU Super-Hard = "relief" (ép tier normal + bonus lượt +
  giảm target nhẹ) → người chơi nghỉ + tích tài nguyên.
- **Áp vào curve**: Hard/Super-Hard siết slack (target/lượt gắt hơn), relief nới.
  Giữ winnability (playtest re-validate).
- **Badge**: hiện chấm/nhãn độ khó trên tile Level Select + World Map (màu theo tier:
  Normal lime · Hard amber · Super-Hard đỏ).

## Test
- Phân bố tier ~70/25/5 (dung sai); levelTier tất định; sawtooth (sau super-hard có
  relief); playtest 0 màn "quá khó" sau khi siết.

## i18n
`tier_normal`/`tier_hard`/`tier_super` (en+vi, 20 ngôn ngữ fallback).
