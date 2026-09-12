---
id: FEAT-45
title: "SeededRandomService — RNG deterministic, loot table và snapshot state"
type: feature
layer: game/utils
priority: P1
effort: M
depends_on: [ENH-56]
unblocks: [IDEA-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là developer/QA, tôi muốn mọi random gameplay tái lập được từ seed để test và replay chính xác.

## Sprint slices
- RNG instance có seed explicit; next int/double/bool/shuffle/pick.
- Weighted table pre-validation và immutable compiled table.
- Snapshot/restore state có algorithm version; stream/fork theo namespace.
- Bridge `weightedRandomPick` cũ và replay diagnostics.

## Acceptance criteria
- [ ] Cùng seed + call sequence cho cùng output trên supported platforms.
- [ ] Range/weight/NaN/empty invalid fail trước khi tiêu RNG state.
- [ ] Snapshot restore tiếp tục đúng sequence; version sai bị reject.
- [ ] Không dùng global `Random()` trong sample gameplay sau migration.

## Prompt loop feature
Đọc task và RNG/replay code; dùng golden vectors TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test seed/range/snapshot/invalid/distribution sanity; analyze/test root + example; smoke device thật so replay hash. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.
