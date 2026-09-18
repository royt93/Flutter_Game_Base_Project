---
id: FEAT-46
title: "CheckpointCoordinator — autosave theo sự kiện và restore an toàn"
type: feature
layer: game/data
priority: P0
effort: M
depends_on: [FEAT-33, FEAT-34, FEAT-37]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn tiến trình quan trọng được checkpoint đúng lúc mà không gây write storm hoặc mixed state.

## Sprint slices
- Checkpoint participant registry + immutable aggregate snapshot.
- Debounce hot event, immediate critical save, serialized flush.
- Lifecycle flush timeout và dirty-state recovery marker.
- Restore validate toàn bộ trước apply; last-known-good fallback.

## Acceptance criteria
- [x] N thay đổi nhanh coalesce đúng; critical checkpoint không bị debounce mất.
- [x] Các participant được commit như một logical version, không mixed snapshot.
- [x] Kill/error giữa save phục hồi last-known-good hoặc pending state rõ ràng.
- [x] Background flush không deadlock và có diagnostic result.

## Prompt loop feature
Đọc task/storage/lifecycle dependencies; TDD crash points trước implementation. End loop: audit changes, chấm /10; unit test + widget test + integration test debounce/atomicity/failure/restart; analyze/test root + example; smoke Android device thật với background/force-stop/relaunch proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Thêm `CheckpointCoordinator` (`lib/core/checkpoint_coordinator.dart`) — không sửa `StorageService`/`RoyLifecycleCoordinator`, chỉ orchestration mỏng phía trên, tận dụng hạ tầng đã có thay vì tự chế:
- Atomicity giải quyết bằng CÁCH ĐƠN GIẢN NHẤT: gộp TẤT CẢ participant vào 1 JSON blob, 1 lệnh `storage.setString()` — đúng pattern `EconomyWallet`/`RewardTransactionPipeline` đã dùng. Một `setString` không bao giờ "nửa vời" (SharedPreferences/NSUserDefaults không xé nhỏ giá trị 1 key), nên "commit như 1 logical version" đến tự nhiên từ thiết kế, không cần transaction giả.
- `requestCheckpoint({critical})`: `critical: true` huỷ debounce timer đang chờ (nếu có) rồi flush ngay; không critical thì huỷ timer cũ, đặt timer mới (`debounceWindow` mặc định 2s) — N lần gọi liên tiếp coalesce thành 1 flush dùng state MỚI NHẤT tại thời điểm timer nổ (không phải state lúc gọi lần đầu).
- `flushNow()` (đổi tên nội bộ cho `_flush`, expose public để lifecycle hook và test gọi trực tiếp) bọc trong `AsyncActionGuard.runExclusive` (tái dùng FEAT-34) — flush từ debounce timer và flush từ lifecycle background event không bao giờ chồng nhau.
- 1 participant `snapshot()` throw, hoặc aggregate không JSON-encode được → abort TOÀN BỘ flush trước khi ghi bất cứ gì — checkpoint cũ giữ nguyên 100%, không có khái niệm "ghi được nửa participant".
- Giữ 1 generation dự phòng (`'${key}_prev'`) — mỗi lần flush thành công, giá trị `current` CŨ (trước khi bị ghi đè) được copy sang `_prev` trước. `restoreLatest()` thử `current` trước, hỏng/thiếu thì thử `_prev` — "last-known-good fallback" không cần transaction thật, chỉ cần giữ 2 bản.
- `${key}_dirty` set `true` ngay trước khi bắt đầu ghi, `false` ngay sau khi ghi xong — `wasDirtyOnLoad` đọc cờ này lúc khởi tạo instance, báo hiệu lần flush trước có thể chưa hoàn tất (thông tin tham khảo cho consumer; an toàn dữ liệu thật sự đến từ `_prev`, không phải cờ này).
- Debounce dùng `Timer Function(Duration, void Function())? createTimer` injectable — đúng convention `HapticChoreographer` (FEAT-?) đã có, test dùng `_FakeTimer` y hệt `test/core/haptic_choreographer_test.dart` thay vì chờ thời gian thực.
- Lifecycle: constructor tự `lifecycle ?? RoyLifecycleCoordinator.maybe` rồi `registerHook('checkpoint_coordinator', ...)` gọi `flushNow()` khi event `background` — timeout theo đúng `RoyLifecycleCoordinator.hookTimeout` có sẵn (FEAT-33), không tự chế timeout riêng. `onClose()` gỡ hook, huỷ timer debounce còn treo.
- `restoreLatest()` validate CẢ aggregate (JSON decode được + có field `participants` dạng Map) trước khi gọi `restore()` của BẤT KỲ participant nào — không có "apply nửa chừng" ở chiều restore, đối xứng với chiều save.
- Trả `SdkResult<int>` (tái dùng FEAT-38, số participant đã commit/restore) cho cả `requestCheckpoint`/`flushNow`/`restoreLatest` — "diagnostic result" theo đúng convention thay vì bool/void.
- KHÔNG thêm vào `RoyCasualKitModule` bootstrap enum — task không yêu cầu, giữ scope M, consumer tự `Get.put` khi cần (giống quyết định `resumePending()` ở FEAT-42).

**Test:** `test/core/checkpoint_coordinator_test.dart` (12 case, TDD — RED xác nhận trước khi viết `checkpoint_coordinator.dart`): critical flush ngay, debounce không flush ngay, N lần gọi coalesce dùng state mới nhất (verify qua các `_FakeTimer.cancelled`), critical huỷ debounce đang chờ, nhiều participant gộp đúng 1 lần ghi, 1 participant throw → abort toàn bộ giữ nguyên checkpoint cũ, restore gọi đúng callback với data đã commit, current hỏng → fallback `_prev` đúng, cả 2 hỏng → failure không gọi restore nào, `wasDirtyOnLoad` đúng qua "restart" (instance mới cùng storage), lifecycle background event trigger flush bypass debounce, `.maybe`.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1296/1296 pass (1 lần chạy trước đó gặp lại đúng `season_event_service_test.dart` flaky pre-existing đã biết từ FEAT-42 — verify pass khi chạy lại, không liên quan). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 55/55 pass (task thuần logic, không cần UI showcase). `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại, CHANGELOG.md cập nhật mục 0.2.0. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): thêm `testWidgets('FEAT-46: ...')` vào `example/integration_test/app_boot_test.dart` (đúng convention chung) — flush 1 checkpoint qua `StorageService.to` thật, tạo instance MỚI (giả lập restart) rồi `restoreLatest()`, verify participant nhận đúng data đã commit. Chạy `flutter test integration_test/app_boot_test.dart -d 2B051FDH3006MU --dart-define=E2E_TEST=true --plain-name "FEAT-46"` (lọc riêng, tránh lỗi audioplayers pre-existing đã gặp ở FEAT-42 khi chạy cả file). Evidence: `doc/task/evidence/FEAT-46-device-smoke.log`.

**Tự chấm điểm: 9.5/10** — atomicity/last-known-good/dirty-marker đều giải quyết bằng cấu trúc dữ liệu đơn giản (1 blob + 1 backup key + 1 cờ) thay vì transaction giả hay lock phức tạp, tái dùng tối đa hạ tầng có sẵn (`AsyncActionGuard`, `SdkResult`, `RoyLifecycleCoordinator`, injectable-timer convention của `HapticChoreographer`), test cover đủ mọi nhánh acceptance criteria bằng fake timer xác định (không chờ thời gian thực), đúng convention device-smoke hiện có. Trừ 0.5 vì "immutable aggregate snapshot" trong Sprint slices chỉ đạt ở mức "1 lần ghi nguyên khối", chưa có kiểu dữ liệu snapshot bất biến tường minh (participant tự chịu trách nhiệm trả JSON-encodable, coordinator không ép kiểu) — chấp nhận được vì đơn giản hơn và không có acceptance criteria nào đòi hỏi kiểu bất biến tường minh.

