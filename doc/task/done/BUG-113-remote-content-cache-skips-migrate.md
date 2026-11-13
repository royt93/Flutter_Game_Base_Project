---
id: BUG-113
title: "RemoteContentPack: cache ghi ở schema cũ bỏ qua migrate, rơi về asset"
type: bug
layer: lib/core/remote_content_pack
priority: P2
effort: S
source: "Scan SDK 2026-11-13 (fork); tự tái hiện độc lập trước khi sửa"
---

## Vị trí
`lib/core/remote_content_pack.dart` `_tryLoadFromCache`: chỉ từ chối `schemaVersion` mới hơn, còn bản cũ hơn đi thẳng vào `fromJson`. Comment cũ giả định cache luôn ghi ở đúng schema hiện tại, nhưng nâng app (schema 1 sang 2) phá giả định đó.

## Tái hiện (đã chạy)
Cache `{id, title, schemaVersion: 1}`, pack schema 2 có `migrate`: `load()` trả nội dung của asset đóng gói (`fromJson` ném trên shape cũ, bị nuốt), `migrate` không được gọi, nội dung live-ops mới hơn trong cache bị bỏ cho tới lần fetch thành công kế tiếp.

## Đã sửa
`_tryLoadFromCache` đi qua `_validateSchema` (cùng đường với asset và envelope tải về): cache cũ được `migrate`, cache mới hơn bị từ chối, cache cũ khi pack không có `migrate` rơi về asset (kiểm chứng, giữ hành vi an toàn). Test `BUG-113` (đỏ khi bỏ sửa, xanh khi có); `test/core` 2015 test và API gate giữ xanh.
