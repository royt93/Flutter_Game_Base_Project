---
id: FEAT-219
title: "Gacha/pity helper: bảng loot có bảo hiểm sau N lần không ra hiếm, seeded, serializable"
type: feature
layer: lib/core
priority: P3
effort: S
source: "Đề xuất của Claude 2026-11-23, owner chọn đưa vào backlog"
---

Kit có `weightedRandomPick` và `CompiledWeightedTable<T>` (utils) nhưng không có bảo hiểm (pity). Quét `lib`: chỉ có một nhắc "gacha" trong doc của `weighted_random_pick.dart`.

## Phạm vi đề xuất

- `PityTable<T>` thuần Dart: bảng trọng số + quy tắc "sau `pityAfter` lần liên tiếp không ra hạng `rare` thì lần kế tiếp ép ra", bộ đếm trạng thái có `toJson/fromJson` (đi qua `VersionedJsonStore`), nhận `Random` (SeededRandom) để tái lập.
- Validate bằng `ArgumentError` ở constructor (trọng số > 0, `pityAfter` > 0, hạng bảo hiểm có trong bảng) theo ENH-85; JSON không tin cậy đi qua `safe_json`.
- Test: đảm bảo không bao giờ vượt `pityAfter` lần trượt, bộ đếm reset đúng sau khi ra, tái lập với cùng seed, round-trip save; mutation check.

## Rủi ro đã nêu

Loot box có quy định theo từng vùng (tỉ lệ công bố, tuổi). README/doc phải ghi: đây chỉ là công cụ xác suất, không phải tư vấn pháp lý; không có UI mua.

## Câu hỏi mở

Một hay nhiều hạng bảo hiểm (soft/hard pity), có "tỉ lệ tăng dần" kiểu soft pity hay chỉ ngưỡng cứng. Đề xuất: ngưỡng cứng ở bản đầu.
