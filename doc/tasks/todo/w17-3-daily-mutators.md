---
id: w17-3-daily-mutators
title: Hằng ngày → Mutator xoay ngày
wave: 17
phase: 3
status: todo
owner: claude
---

# Phase 3 — Hằng ngày: MUTATOR xoay theo ngày (hết reskin objective campaign)

## Vấn đề hiện tại (audit)
Hằng ngày = chọn lại 1 trong 6 objective campaign + seed bàn theo `epochDay` + thưởng/
streak. Khác biệt duy nhất = bàn cố định theo ngày. **Không cơ chế mới.**

## Thiết kế mới — Mutator (luật biến tấu) theo ngày
Mỗi ngày chọn 1 (hoặc 2) **mutator** tất định theo `epochDay` → cùng luật toàn cầu,
tạo "vị" mới mỗi ngày + lý do quay lại:
- `only4Colors` — chỉ 4 màu (dễ combo, khó tránh match ngoài ý).
- `sideGravity` — trọng lực NGANG (tái dùng Gravity-stream flow của W15).
- `doubleCombo` — điểm combo ×2 (vui, dễ).
- `lowMoves` — −30% lượt (gắt).
- `bigBoard` — 9×9 thay vì 8×8 (nếu engine hỗ trợ rows/cols động — đã có tham số).
- `allJelly` — phủ jelly toàn bàn.
- `noSpecial` — match-4/5 KHÔNG tạo special (thuần match-3).

## Triển khai
- `lib/data/levels.dart`: `enum DailyMutator`, `dailyMutatorsFor(epochDay)` (tất định,
  trả 1-2 mutator), bake vào `buildDailyLevel` (đổi colorCount/moves/objective/flow…).
- Engine `neon_jewel_game.dart`: đa số mutator áp qua CONFIG (colorCount, moves, flow,
  jelly) — ít cần hook engine mới; `doubleCombo`/`noSpecial` cần đọc cờ ở scoring/special.
- UI: HUD/pre-game hiện badge "Mutator hôm nay: …" + Guide giải thích.
- i18n: tên + mô tả mỗi mutator (en/vi + 20 ngôn ngữ fallback).

## Test
- `dailyMutatorsFor` TẤT ĐỊNH theo ngày (cùng epochDay → cùng mutator).
- Mỗi mutator áp đúng (4 màu → colorCount=4; lowMoves → moves giảm; noSpecial → match-4
  không tạo striped…).
- Mọi mutator vẫn WINNABLE (sim/curve check; lowMoves không làm bất khả thi).
- ISOLATION + thưởng/streak 1 lần/ngày giữ nguyên.

## Lưu ý
- Phần lớn mutator tái dùng tham số/flow CÓ SẴN → rẻ. Tránh mutator phá winnability
  (lowMoves cần sàn an toàn; allJelly cần đủ lượt).
- Liên quan: [[daily-challenge-subsystem]], [[w11-weave-mechanics]], [[side-mode-isolation]].
