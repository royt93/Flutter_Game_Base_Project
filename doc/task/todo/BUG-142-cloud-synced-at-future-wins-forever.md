---
id: BUG-142
title: "syncWith: cloud có syncedAtMs ở tương lai xa thắng local mãi mãi"
type: bug
layer: lib/core
priority: P2
effort: S
source: "Chaos survey 2026-11-23 (test chạy thật, đã xoá)"
---

## Bằng chứng

`VersionedJsonStore.syncWithResult` so `cloudTime > localTime` thuần. Cloud `{schemaVersion:1, syncedAtMs: 9999999999999, coins: 5}` ghi đè local `{coins: 100}` (đã đo), và vì timestamp ở tương lai, mọi `save()` honest sau đó (timestamp = `nowMsClamped`) đều thua cloud ở lần sync kế: dữ liệu local bị ghi đè lặp lại cho tới khi thời gian thật đuổi kịp.

Nguồn timestamp lạ: máy khác có đồng hồ sai, cloud payload bị sửa, hoặc bug provider.

## Đề xuất

Khi đọc `cloudTime`, nếu `cloudTime > nowMsClamped(storage) + dung sai` (vd 24h), coi là không tin cậy: không để nó thắng tự động; đi qua `onConflict` nếu có, không thì giữ local và upload local. Cần owner chốt dung sai và hành vi.

## Cần có khi làm

- Test: cloud xa tương lai không ghi đè local; cloud hợp lệ mới hơn vẫn thắng; cloud trong dung sai vẫn thắng.
- Ghi **Behavior change** CHANGELOG.
- Lưu ý: `asIntOr` đã chặn non-finite; đây là giá trị hữu hạn hợp lệ nhưng phi lý.
