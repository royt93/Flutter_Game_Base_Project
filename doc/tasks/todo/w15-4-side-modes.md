---
id: w15-4-side-modes
title: 2 chế độ phụ mới — Mê cung neon + Sinh tồn
wave: 15
phase: 4
status: todo
owner: claude
---

# Phase 4 — Labyrinth + Survival (cả hai)

Cô lập side-mode đầy đủ (getter `isSideMode`, checkEnd/again/resultPanel nhánh
riêng, KHÔNG đụng mạng/streak/unlock). [[side-mode-isolation]]

## Mê cung neon (Labyrinth) — showcase blocked-cell
- `isLabyrinth` + `buildLabyrinthLevel()`: bàn có **tường tạo mê cung** (dùng hệ
  Phase 0/1/2). Mục tiêu: đưa "tinh thể" (ingredient, tái dùng Drop Down) từ ô
  nguồn xuống **cổng đích** qua khe hẹp — clear gem để tinh thể chảy theo flow.
- Thắng khi đủ K tinh thể tới đích. HUD chip mục tiêu + nút Home + Guide.

## Sinh tồn (Survival)
- `isSurvival` + `buildSurvivalLevel()`: đồng hồ đếm ngược (vd 60s), mỗi combo
  ≥3 → +giây; hết giờ → kết thúc, điểm = thành tích. Sống càng lâu điểm càng cao.
- Tái dùng timer-in-update của Time Attack. HUD TIME + điểm. Nút Home + Guide.

## Test
- Labyrinth: tinh thể chảy đúng theo flow/mê cung tới đích; đủ K → win; side-mode
  isolation. Survival: combo +giây; hết giờ → end + thưởng theo điểm; isolation.

## i18n
en+vi cho `labyrinth_*`/`survival_*`/`guide_*`; 20 ngôn ngữ qua `_w15ByLang`.
