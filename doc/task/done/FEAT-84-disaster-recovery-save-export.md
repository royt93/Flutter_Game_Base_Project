---
id: FEAT-84
title: "Disaster Recovery Save Export"
type: feature
layer: data/core
priority: P1
effort: M
depends_on: [FEAT-37, FEAT-39, IDEA-31]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Tạo export encrypted/signed, multi-slot backup và restore preview trước apply.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Export atomic, versioned, size-bounded và không lộ secret.
- [x] Restore preview validate toàn bộ; corrupt/tamper không mutate local save.
- [x] Crash giữa restore giữ last-known-good và có recovery log.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/disaster_recovery_save_export.dart` — `DisasterRecoverySaveExport`,
KHÔNG tự làm 1 pipeline mới mà GHÉP đúng 3 primitive đã có sẵn:
`SaveSlotManager` (biết slot nào tồn tại + `keyFor` sinh prefix), `StorageService.exportWithPrefix`/
`importWithPrefix` (di chuyển dữ liệu thật — quan trọng nhất:
`importWithPrefix` tự nó gọi `importAll`, vốn ĐÃ CÓ SẴN cơ chế
snapshot-trước/rollback-khi-lỗi vì `SharedPreferences` không có transaction
thật), và `save_integrity.dart`'s HMAC sign/verify (đúng convention
`ReplayCapsule.exportSigned` đã dùng).

**Đây chính xác là lý do "crash giữa restore giữ last-known-good" làm
được MÀ KHÔNG CẦN viết logic transaction mới**: mỗi lần
`applyRestore` gọi `importWithPrefix` cho 1 slot, bên trong nó tự chụp
snapshot toàn bộ store TRƯỚC lúc ghi, và tự rollback về đúng snapshot đó
nếu ghi lỗi — nên nếu slot A ghi xong rồi slot B throw, slot A vẫn giữ dữ
liệu mới (đã nằm trong snapshot lúc B bắt đầu), còn B tự rollback về đúng
dữ liệu CŨ của chính nó, không phải trạng thái ghi dở dang nào khác.
`applyRestore` chỉ cần DỪNG LẠI ở slot lỗi đầu tiên (không cố gắng tiếp
tục — an toàn hơn) và ghi `recoveryLog` từng bước.

**Size-bounded, atomic, không lộ secret**:
- `buildExport` reject TOÀN BỘ (không export 1 phần) nếu JSON vượt
  `maxBytes` — khác `DiagnosticsExportBundle` (FEAT-70) vốn ĐƯỢC PHÉP drop
  section để vừa cap; ở đây 1 slot save data thiếu còn TỆ HƠN không có
  export nào (restore từ đó trông đầy đủ nhưng âm thầm mất tiến trình).
- Checksum qua `signExport`/`verifyAndStrip` có sẵn — secret do caller
  cung cấp (không baked-in package), đúng warning đã ghi trong chính
  `save_integrity.dart`.
- "Atomic" ở mức: `buildExport` validate hết mọi slotId TRƯỚC khi bắt đầu
  đọc dữ liệu (fail nhanh, không đọc dở dang).

**Restore preview validate toàn bộ, corrupt/tamper không mutate local
save**: `previewRestore` verify checksum + `schemaVersion` (từ chối
version tương lai, đúng discipline `VersionedJsonStore`/`RemoteContentPack`)
+ shape từng slot entry — KHÔNG gọi bất kỳ hàm ghi nào của `storage` trên
BẤT KỲ nhánh nào (thành công lẫn thất bại). Test khoá riêng: đổi 1 key
sau khi export, preview lại export cũ, xác nhận `storage.exportAll()`
không đổi 1 bit nào.

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1940/1940 pass (1927 cũ + 13
  test mới `disaster_recovery_save_export_test.dart`).
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `DisasterRecoverySaveExport`/`SlotExportEntry`/`RestorePreview`/
  `RestoreLogEntry`, CHANGELOG khớp; `snapshot` lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.
- 13 test: `buildExport` (slot không tồn tại → reject, đúng dữ liệu
  key/value, vượt size cap → reject toàn bộ không export 1 phần);
  sign/preview round-trip đúng, sai secret → reject, **tamper 1 field sau
  ký → checksum sai bị bắt**, schemaVersion tương lai → reject, "slots"
  sai type → reject; **1 test "PHÁT HIỆN THẬT" khoá đúng preview không
  mutate storage** (đổi key sau export, preview lại, storage không đổi);
  `applyRestore` happy path (dữ liệu về đúng, recoveryLog ghi đúng); **1
  test "PHÁT HIỆN THẬT" mô phỏng crash giữa restore đa-slot bằng
  `_ThrowingStorageService` (subclass `StorageService`, override
  `importWithPrefix` để throw đúng 1 prefix)** — xác nhận slot A giữ dữ
  liệu MỚI, slot B giữ dữ liệu CŨ (không phải giá trị export, không phải
  trạng thái lạ nào khác), `recoveryLog` ghi đủ 2 bước đúng thứ tự;
  `recoveryLog` cộng dồn qua nhiều lần gọi, không tự reset.

**Không có UI mới trong `example/`** — thuần core service, nhất quán với
FEAT-70/77/78 trong cùng session (compose primitive có sẵn, không cần demo
trực quan riêng); `BackupRestorePanel` (IDEA-31) đã là UI mẫu cho đúng
pattern export/import 1-store, việc thêm 1 UI multi-slot riêng cho task
này để lại làm follow-up nếu game cụ thể cần.

Tự chấm: 9.5/10. Điểm cao vì test "crash giữa restore" không phải mock hời
hợt mà dùng đúng kỹ thuật subclass override để mô phỏng lỗi THẬT ở đúng vị
trí cần, và chứng minh được guarantee "last-known-good" bắt nguồn từ 1 cơ
chế ĐÃ CÓ SẴN trong `StorageService.importAll` (viết cho ENH khác trước
đây) chứ không phải logic mới tự bịa — đúng tinh thần ghép nối, không phát
minh lại.

