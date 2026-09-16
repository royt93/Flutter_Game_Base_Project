---
id: BUG-37
title: "RemoteContentPack: schemaVersion vắng mặt bị coi là 'đã current' (bỏ qua migrate), khác hẳn VersionedJsonStore coi là 'version 0' (cũ nhất)"
type: bug
priority: medium
effort: S
source: Claude (self-generated backlog audit — đọc trực tiếp `lib/core/remote_content_pack.dart` và `lib/core/versioned_json_store.dart`)
---

## Vị trí
Sửa lỗi — `lib/core/remote_content_pack.dart` (`RemoteContentPack._validateSchema`, dòng 130).

## Hiện trạng
2 class trong cùng repo đều làm đúng 1 việc — "đọc `schemaVersion` từ 1 JSON envelope chưa được tin cậy, quyết định có cần `migrate` hay không" — nhưng xử lý field `schemaVersion` VẮNG MẶT (không tồn tại trong JSON, khác với "tồn tại nhưng sai kiểu") theo 2 CÁCH NGƯỢC NHAU:

- `lib/core/versioned_json_store.dart:132`: `final storedVersion = asIntOr(decoded['schemaVersion'], 0);` — vắng mặt → coi là **version 0** (cũ nhất có thể) → LUÔN chạy qua `migrate(0, decoded)` nếu store hiện tại có `schemaVersion > 0`.
- `lib/core/remote_content_pack.dart:130`: `final storedVersion = asIntOr(json['schemaVersion'], schemaVersion);` — vắng mặt → coi là **đã đúng version hiện tại** (`this.schemaVersion`) → BỎ QUA `migrate` hoàn toàn, đưa thẳng JSON (có thể vẫn ở shape CŨ) vào `fromJson`.

Xác nhận qua đọc `test/core/remote_content_pack_test.dart`: **TẤT CẢ** test case đều truyền `'schemaVersion': ...` tường minh trong JSON mẫu (dòng 41, 70, 99, 124, 149, 176, ...) — không có test nào cho trường hợp field này HOÀN TOÀN VẮNG MẶT, nên hành vi khác biệt này chưa từng được xác nhận có chủ đích hay không.

## Vì sao cần / Hậu quả
`RemoteContentPack` dùng cho nội dung live-ops (level definition, shop catalog, event schedule) — 1 file asset JSON được author (thường là non-engineer, chỉnh tay) rất dễ QUÊN thêm field `schemaVersion` khi tạo file asset lần đầu (đặc biệt nếu asset đó được viết TRƯỚC khi `migrate` từng cần tồn tại). Với hành vi hiện tại: nếu sau này `schemaVersion` của pack tăng lên (ví dụ đổi tên field, đổi cấu trúc list) và asset cũ vẫn thiếu field này, `_validateSchema` coi nó là "đã current", bỏ qua `migrate`, đưa thẳng shape CŨ vào `fromJson` — kết quả tuỳ vào `fromJson` của consumer: có thể throw (bị nuốt bởi `catch (_)`, `current` giữ nguyên `null`/giá trị cũ, im lặng không có nội dung mới) hoặc TỆ HƠN, nếu `fromJson` không validate đủ chặt, ÂM THẦM tạo ra 1 `T` sai/thiếu field mà không ai biết. Đây chính xác là loại lỗi "vô tình mất nội dung live-ops mới mà không có log/crash nào cả" — khó phát hiện, chỉ lộ ra khi QA/người chơi báo cáo nội dung "không đúng như dự kiến".

## Đề xuất
Đổi `_validateSchema` trong `RemoteContentPack` để dùng CÙNG default `0` cho field vắng mặt, giống hệt `VersionedJsonStore`:

```dart
final storedVersion = asIntOr(json['schemaVersion'], 0);
```

Điều này bắt buộc mọi envelope thiếu `schemaVersion` phải đi qua `migrate` (nếu pack có `schemaVersion > 0` và có cung cấp `migrate`) — nếu KHÔNG có `migrate` được cung cấp, giữ nguyên hành vi hiện tại của nhánh `storedVersion < schemaVersion` (`if (migrateFn == null) return null;` — từ chối an toàn thay vì đoán mò), đây CHÍNH LÀ hành vi mong muốn cho 1 asset thiếu version mà không có cách nào để migrate.

**Cân nhắc quan trọng khi implement**: đổi default này có thể làm 1 số asset THẬT ĐANG THIẾU field `schemaVersion` (nhưng thực ra đúng shape hiện tại, chỉ là author quên thêm field) đột nhiên bị coi là "version 0" và bị từ chối (nếu không có `migrate`) thay vì được chấp nhận như trước — đây là thay đổi hành vi có chủ đích (đúng tinh thần "an toàn hơn là đoán mò"), nhưng cần verify không phá bất kỳ test hiện có nào (tất cả test hiện tại đều truyền `schemaVersion` tường minh nên không bị ảnh hưởng — chỉ 1 test case MỚI cho "field vắng mặt" mới lộ ra khác biệt).

## Acceptance criteria
- [x] `RemoteContentPack._validateSchema` dùng default `0` cho `schemaVersion` vắng mặt, khớp đúng convention của `VersionedJsonStore`.
- [x] Envelope thiếu `schemaVersion`, pack có `schemaVersion > 0` VÀ có `migrate`: chạy qua `migrate(0, json)` đúng, không bỏ qua.
- [x] Envelope thiếu `schemaVersion`, pack có `schemaVersion > 0` NHƯNG không có `migrate`: bị từ chối an toàn (`null`/giữ `current` cũ), không throw, không âm thầm nhận shape sai.
- [x] Envelope thiếu `schemaVersion`, pack có `schemaVersion == 0` (mặc định, no versioning cần thiết): vẫn được chấp nhận bình thường (giá trị mặc định 0 khớp đúng, không coi là "cũ hơn").
- [x] Không phá bất kỳ test hiện có nào trong `test/core/remote_content_pack_test.dart` (tất cả đều truyền `schemaVersion` tường minh, không phụ thuộc vào default).
- [x] Test: bổ sung case "field vắng mặt" cho cả `load()` (asset) lẫn `fetchRemote` (network) — cả 2 code path đều đi qua `_validateSchema`.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-37-remote-content-pack-missing-schema-version-inconsistent-default.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/remote_content_pack.dart`, `lib/core/versioned_json_store.dart` (đặc biệt `_validate`/dòng 132), và `test/core/remote_content_pack_test.dart` hiện có để hiểu đúng convention trust-boundary trước khi sửa. Implement bằng TDD (viết test fail trước cho case "schemaVersion vắng mặt", rồi sửa `asIntOr` default cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với `VersionedJsonStore`, không phá test cũ, không over-engineer — chỉ đổi đúng 1 giá trị default).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (đây là thay đổi core service thuần, không cần đụng `example/`).
4. Không cần device smoke test (logic thuần JSON parsing, không có UI liên quan trực tiếp).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp 2 file: `versioned_json_store.dart:132` dùng default `0`, `remote_content_pack.dart:130` dùng default `schemaVersion` (giá trị hiện tại) — 2 dòng gần như giống hệt nhau về mục đích nhưng đối lập nhau về default. Xác nhận thêm qua đọc TOÀN BỘ `test/core/remote_content_pack_test.dart`: không có test nào cho case field vắng mặt, nên đây không phải hành vi đã được xác nhận có chủ đích. Effort nhỏ (đổi 1 giá trị default + test), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Sửa đúng 1 dòng như đề xuất: `asIntOr(json['schemaVersion'], schemaVersion)` → `asIntOr(json['schemaVersion'], 0)` — khớp chính xác convention `VersionedJsonStore._validate` (dòng 132) đang dùng. Không đụng nhánh `migrate == null` (đã đúng sẵn: từ chối an toàn, trả `null`/giữ `current`).

**Test:** 5 test mới trong `test/core/remote_content_pack_test.dart` nhóm "BUG-37" — cả 2 code path (`load()` từ asset VÀ `fetchRemote` qua network, đúng yêu cầu "cả 2 đều đi qua `_validateSchema`"): thiếu field + có `migrate` → chạy đúng `migrate(0, json)`; thiếu field + không `migrate` → từ chối an toàn không throw; `schemaVersion == 0` (mặc định) + thiếu field → vẫn chấp nhận bình thường (0 khớp đúng 0, không bị coi là cũ hơn). 4/5 test FAIL đúng như dự đoán trước khi sửa (xác nhận bug thật, không phải suy đoán suông), pass ngay sau khi đổi 1 dòng.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1154/1154 pass. Không đụng `example/` (logic JSON thuần, không có UI liên quan).

**Tự chấm điểm: 9.5/10** — sửa đúng 1 lỗi thật có bằng chứng cụ thể (2 class cùng mục đích, đối lập hành vi), thay đổi tối thiểu (1 dòng), test bao phủ đúng cả 2 code path (asset + network) theo đúng yêu cầu khó nhất trong acceptance criteria, xác nhận bug bằng TDD thật (test fail trước khi sửa) chứ không chỉ đọc code suông. Đây là loại lỗi "mất nội dung live-ops âm thầm, không log/crash" — mức độ nghiêm trọng đáng kể dù effort sửa nhỏ.
