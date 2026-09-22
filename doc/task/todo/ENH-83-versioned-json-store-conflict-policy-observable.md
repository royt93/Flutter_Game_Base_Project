---
id: ENH-83
title: "VersionedJsonStore.syncWith chỉ có last-write-wins câm — không có callback quan sát/tuỳ biến conflict"
type: enhancement
priority: P1
effort: M
source: "codex (độc lập)"
---

## Vị trí
`lib/core/versioned_json_store.dart` — `syncWith(CloudSaveProvider provider)` (~dòng 143).

## Hiện trạng
Conflict resolution hiện tại chỉ dựa `syncedAtMs` (last-write-wins) — timestamp bằng nhau tự chọn local rồi upload lại. Không có callback nào để consumer app hiển thị "giữ bản nào", log telemetry, hoặc tự merge domain data khi có xung đột (clock lệch giữa 2 thiết bị, hoặc offline edit trên cả 2 máy).

## Vì sao cần / Hậu quả
Cloud save đa thiết bị (điện thoại + tablet cùng tài khoản) là tình huống thực tế phổ biến — last-write-wins câm có thể âm thầm mất tiến trình của 1 thiết bị mà người chơi không hề biết, không có cách nào can thiệp.

## Đề xuất
Thêm kiểu `SyncConflict<T>` (chứa local/remote value + metadata: `syncedAtMs`, checksum, device id) và tham số callback tuỳ chọn cho `syncWith` (`onConflict: SyncConflictResolution<T> Function(SyncConflict<T>)?`) với các chiến lược có sẵn (`preferLocal`, `preferCloud`, `manual` — chờ callback quyết định). Giữ hành vi mặc định (last-write-wins) nếu không truyền callback — không breaking change.

## Acceptance criteria
- [ ] `syncWith` nhận `onConflict` optional, mặc định `null` giữ nguyên hành vi last-write-wins hiện tại.
- [ ] Khi có callback, conflict (timestamp bằng nhau HOẶC checksum khác nhau dù timestamp khác) gọi đúng callback, dùng kết quả callback trả về để quyết định giữ local/cloud/merge.
- [ ] Callback ném exception không làm crash `syncWith` — fallback về last-write-wins, log lỗi.
- [ ] Test: timestamp bằng nhau, clock lệch (remote timestamp "trong tương lai" so với local), callback throw, cloud data malformed.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-83-versioned-json-store-conflict-policy-observable.md` này trước khi làm. Đọc toàn bộ `lib/core/versioned_json_store.dart` và `lib/core/cloud_save_provider.dart` (seam interface) và test hiện có trước khi thêm API mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root, và `dart run tool/api_compatibility.dart check`/`snapshot` nếu thêm export mới.
4. Không cần smoke test device bắt buộc (logic thuần cloud-sync, không có UI demo hiện tại).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — codex trích dẫn đúng file/dòng, mô tả kỹ thuật hợp lý và khớp với thiết kế seam-based hiện có của kit (`CloudSaveProvider`). Chưa tự Read lại chi tiết implementation hiện tại của `syncWith`. Không trùng task nào trong `doc/task/done/`.
