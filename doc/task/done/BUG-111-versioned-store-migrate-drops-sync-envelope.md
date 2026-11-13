---
id: BUG-111
title: "VersionedJsonStore: migrate dựng lại map làm mất syncedAtMs/schemaVersion, save cloud schema cũ không khôi phục"
type: bug
layer: lib/core/versioned_json_store
priority: P2
effort: S
source: "Scan SDK 2026-11-13 (fork); tự tái hiện lại độc lập trước khi sửa"
---

## Vị trí
`lib/core/versioned_json_store.dart` `_validate` (nhánh `storedVersion < schemaVersion`) và `syncWith` (`cloudTime = asIntOr(cloudJson['syncedAtMs'], -1)`).

## Tái hiện (đã chạy, test tạm đã xoá)
Máy mới, cloud `{schemaVersion: 0, old: 7, syncedAtMs: 5000}`, hàm `migrate` dựng map mới `{n: m['old']}`: sau `syncWithResult` thì `load()` là `null` và không upload. `cloudTime` đọc từ kết quả đã migrate nên là -1, thua local rỗng. Đối chứng: `migrate` giữ key (`{...m, ...}`) thì khôi phục đúng.

Kiểm thêm khi sửa: ngay cả khi `syncedAtMs` được giữ, bản ghi vào storage mất `schemaVersion` nếu migrate dựng lại map, nên lần `load()` kế tiếp coi là version 0 và migrate lần hai (trong thử nghiệm: `type 'Null' is not a subtype of type 'int'`).

## Tác động
Người chơi đổi máy trong khi cloud còn save ở schema cũ mất tiến trình mà không có lỗi nào báo ra; `migrate` do consumer viết nên không thể trông chờ họ nhớ giữ khoá envelope.

## Đã sửa
`_validate` luôn đặt lại `schemaVersion` hiện tại và chép lại `syncedAtMs` của bản gốc nếu bước migrate không tự đặt. Không đổi chữ ký công khai (API gate unchanged). Test: 3 test BUG-111 trong `versioned_json_store_test.dart` (khôi phục cloud cũ, migrate giữ key không đổi hành vi, migrate tự đặt `syncedAtMs` không bị ghi đè); đã chứng minh 1 test đỏ khi bỏ phần sửa. `test/core` và `test/tool` xanh.

## Chưa làm
`SaveMigrationRegistry.migrate` không kiểm bước trả về có đúng phiên bản (fork không tái hiện hậu quả); ghi nhận, không mở task.
