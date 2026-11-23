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

## Kết quả thực hiện (2026-11-23)

- `syncWithResult`: cloud thắng theo thời gian chỉ khi `cloudTime > localTime` VÀ không (có local và `cloudTime > nowMsClamped + maxCloudClockSkewMs`). Dung sai 24h (`VersionedJsonStore.maxCloudClockSkewMs`, owner chưa chỉnh nên giữ mặc định đề xuất). Cloud quá xa: giữ local và upload local. `onConflict` vẫn nhận timestamp thật. Không có local: cloud vẫn restore.
- Test: 4 mới (xa tương lai giữ local + upload; không có local vẫn restore; trong dung sai vẫn thắng; onConflict thấy timestamp thật). Mutation (guard thành `false`) làm 1 test đỏ đúng.
- Giới hạn: dung sai là hằng static, chưa cấu hình theo store; chưa xử lý cloud xa tương lai khi có `onConflict` trả `preferCloud` (handler quyết định).
- Kiểm chứng và CHANGELOG như BUG-141.
