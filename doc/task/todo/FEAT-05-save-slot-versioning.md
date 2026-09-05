---
id: FEAT-05
title: Save-slot/progress model chuẩn hoá có versioning
type: feature
priority: P1
effort: M
source: agy + claude-CLI
---

## Vì sao cần
`StorageService` hiện chỉ có key-value phẳng (int/bool/string/double). Game
có level/map/player profile cần 1 lớp mỏng serialize/deserialize JSON có
version, để migrate được khi schema đổi giữa các bản game — hiện phải tự viết
lại từ đầu mỗi lần.

## Đề xuất phạm vi
- 1 helper `VersionedJsonStore<T>` (hoặc tên tương đương): đọc/ghi 1 object
  JSON qua `StorageService.setString`/`getString` hiện có, kèm field
  `schemaVersion` và callback `migrate(int fromVersion, Map json)`.
- Không cần implement sẵn schema cụ thể nào (mỗi game khác nhau) — chỉ cần bộ
  khung migrate dùng chung.

## Acceptance criteria
- [ ] Đổi `schemaVersion` + cung cấp hàm migrate → dữ liệu cũ tự chuyển đổi đúng khi load.
- [ ] Test round-trip: lưu → đổi version → load → migrate đúng.
