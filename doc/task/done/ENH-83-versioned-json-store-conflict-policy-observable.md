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
- [x] `syncWith` nhận `onConflict` optional, mặc định `null` giữ nguyên hành vi last-write-wins hiện tại.
- [x] Khi có callback, conflict (timestamp bằng nhau HOẶC checksum khác nhau dù timestamp khác) gọi đúng callback, dùng kết quả callback trả về để quyết định giữ local/cloud/merge.
- [x] Callback ném exception không làm crash `syncWith` — fallback về last-write-wins, log lỗi.
- [x] Test: timestamp bằng nhau, clock lệch (remote timestamp "trong tương lai" so với local), callback throw, cloud data malformed.

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

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `lib/core/versioned_json_store.dart` thêm `VersionedSyncConflictSide<T>`,
`VersionedSyncConflict<T>`, `VersionedSyncConflictStrategy` (enum:
`preferLocal`/`preferCloud`/`merge`), `VersionedSyncConflictResolution<T>`
(3 named constructor tương ứng), `VersionedSyncConflictHandler<T>` typedef,
và `syncWith(provider, {onConflict})`.

**Định nghĩa "conflict" (quyết định thiết kế, khác 1 chút so với đề xuất
gốc)**: task gốc gợi ý trigger callback khi "timestamp bằng nhau HOẶC
checksum khác nhau" — nhưng kit hiện KHÔNG có hạ tầng checksum/device-id
nào cho `VersionedJsonStore` (không phát minh thêm 1 field mới không cần
thiết). Thay vào đó: callback được gọi khi CẢ 2 phía (local VÀ cloud) đều
có dữ liệu HỢP LỆ VÀ nội dung THẬT SỰ khác nhau (so sánh deep-equal JSON,
bỏ qua field `syncedAtMs`) — bao gồm CẢ trường hợp timestamp bằng nhau LẪN
trường hợp timestamp khác nhau (vì lệch đồng hồ giữa 2 thiết bị khiến
timestamp "mới hơn" không đáng tin, đúng tinh thần "Vì sao cần" của task:
"last-write-wins câm có thể âm thầm mất tiến trình... không có cách nào
can thiệp"). 2 bản ghi giống hệt nhau (chỉ khác `syncedAtMs` — case bình
thường khi resave dữ liệu không đổi) KHÔNG coi là conflict.

**Backward compatible**: `onConflict` optional, mặc định `null` → hành vi
last-write-wins y hệt code cũ, không đổi 1 dòng logic nào của nhánh mặc
định.

**Exception safety**: callback throw → bắt, log qua `dlog()`, fallback về
đúng nhánh last-write-wins mặc định (không rethrow, không để sync nửa
vời).

**Phát hiện + tự sửa 1 lỗi thật giữa chừng (trước khi push, không phải sau
khi push)**: đặt tên ban đầu `SyncConflict`/`SyncConflictHandler`/... —
`flutter test --exclude-tags slow` ở bước cuối phát hiện LỖI BIÊN DỊCH:
`lib/core/offline_outbox_service.dart` ĐÃ CÓ SẴN 1 class tên
`SyncConflict` (khái niệm hoàn toàn khác — kết quả đồng bộ hàng đợi
offline), export cùng barrel gây trùng tên. Đổi toàn bộ 5 type mới sang
tiền tố `VersionedSyncConflict*` (rõ ràng hơn về scope — gắn với
`VersionedJsonStore`, không mơ hồ như `SyncConflict` trần trụi), chạy lại
toàn bộ test + `dart run tool/api_compatibility.dart snapshot` sau khi đổi
tên. Đây đúng lý do bước 3 (chạy full test suite TRƯỚC KHI commit) tồn tại
trong quy trình — bắt được lỗi trước khi push, không phải sau.

**TDD**: 11 test mới `test/core/versioned_json_store_test.dart` (group
"ENH-83") — không truyền `onConflict` giữ nguyên hành vi cũ; nội dung
giống hệt (chỉ khác timestamp) KHÔNG gọi callback; timestamp bằng nhau gọi
đúng callback với đúng local/cloud value+timestamp; clock lệch (cloud
timestamp xa tương lai) vẫn gọi callback thay vì tin timestamp mù quáng;
`preferLocal`/`preferCloud`/`merge` mỗi resolution ghi đúng dữ liệu đúng
chỗ (`merge` ghi CẢ local lẫn cloud); callback throw không crash, fallback
đúng; cloud data hỏng (field sai kiểu) → callback KHÔNG được gọi (chỉ 1
bên hợp lệ, không phải xung đột thật); chỉ 1 bên có data → callback KHÔNG
được gọi. Xác nhận fail đúng lỗi biên dịch khi `git stash` file lib, khôi
phục pass 11/11 (26/26 cả file `syncWith`-related).

**Kết quả**: `flutter analyze` sạch. `flutter test --exclude-tags slow`
root: 2219 test, 19 fail — khớp đúng baseline golden-image macOS-only đã
biết, không có fail mới (sau khi sửa lỗi trùng tên). `dart run
tool/api_compatibility.dart check`: `additive` (5 type mới, tên đã đổi) →
`snapshot` → `unchanged`. Không cần `example/` (không có UI demo liên
quan, task tự ghi rõ không bắt buộc device/example).
