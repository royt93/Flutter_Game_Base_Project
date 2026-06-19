---
id: w15-5-content-worlds
title: Nội dung — Thế giới 6-8 + màn 101-150
wave: 15
phase: 5
status: todo
owner: claude
---

# Phase 5 — Worlds 6-8 + levels 101-150

Đất diễn cho mọi cơ chế Phase 0-3. Mở rộng 100 → 150 màn, thêm 3 thế giới neon.

## Việc
- `kWorlds`: thêm 3 thế giới (6/7/8) — mỗi thế giới 1 accent màu mới
  (`NeonTheme.accentForWorld`) + tên (`world_name_6..8`, proper noun).
- Generator level 101-150: weave dần **bố cục lỗ/tường** (Phase 0), **trượt chéo**
  (Phase 1), **Gravity Streams** (Phase 2), **cage + no-drop** (Phase 3) theo chỉ
  số màn (pattern weave như `kBombLevels`/`kOrderLevels`) — KHÔNG dồn hết 1 chỗ.
- Giữ ĐƯỜNG CONG đã validate: target gắn số lượt (xem [[balance-economy-principles]]).
- World map / Level Select hỗ trợ 150 màn (đã lazy-scroll, kiểm lại).

## Playtest
- Cập nhật `tool/playtest.dart`: bot hiểu **blocked cell** (không match qua wall) +
  flow direction; chạy 101-150 đảm bảo 0 màn "quá khó". [[playtest-simulator]]

## i18n
`world_name_6..8` + key nội dung mới dịch đủ 22 ngôn ngữ (`_w15ByLang`),
coverage test ≥80% vẫn PASS.
