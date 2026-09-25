---
id: BUG-79
title: "ConnectivityCoordinator probe bất đồng bộ ghi vào stream đã đóng"
type: bug
priority: P2
effort: S
source: "claude audit vòng 3 — tái hiện Bad state độc lập"
---

## Vị trí
`lib/core/connectivity_coordinator.dart`.

## Hiện trạng và hậu quả
Probe in-flight hoàn tất sau `onClose()` vẫn gọi `_setState`, dẫn đến `Bad state: Cannot add new events after calling close`; đồng thời có thể drain queue hoặc schedule lại timer sau dispose.

## Acceptance criteria
- [x] Probe hoàn tất sau close không throw/unhandled error.
- [x] Sau close không state mutation, stream add, queue drain hoặc timer mới.
- [x] Lifecycle behavior hiện có vẫn pass.

## Quyết định kỹ thuật
- Thêm cờ private `bool _isClosed = false;` vào `ConnectivityCoordinator`.
- Khi `onClose()` được gọi:
  - Đặt `_isClosed = true;`
  - Hủy và gán `null` cho `_debounceTimer` và `_probeTimer`.
  - Hủy stream subscription `_sub` và đóng `_stateController`.
- Áp dụng early return guard `if (_isClosed) return;` tại mọi asynchronous continuation:
  - `_runProbe()` kiểm tra `_isClosed` trước khi chạy và ngay sau khi `await probe()` hoàn tất để không bao giờ gọi `_setState()` hay `_drainQueue()` khi đã đóng.
  - `_setState()` kiểm tra `_isClosed` và kiểm tra `!_stateController.isClosed` trước khi `add(effective)`.
  - `_drainQueue()` kiểm tra `_isClosed` trước vòng lặp và sau mỗi task execution để dừng drain ngay lập tức.
  - `_handleInterfaceChange`, `_periodicProbe`, `_scheduleInterfaceEvaluation`, `enqueue`, `debugForceState` đều được guard chặt chẽ chống tạo timer mới hoặc làm rò rỉ bộ nhớ.


## Prompt
Làm TDD bằng fake timer và `Completer<bool>` trong `test/core/connectivity_coordinator_test.dart`. Dùng closed/generation guard tại mọi asynchronous continuation phù hợp.
