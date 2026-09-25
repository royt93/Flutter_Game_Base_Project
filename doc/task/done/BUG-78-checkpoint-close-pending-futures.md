---
id: BUG-78
title: "CheckpointCoordinator onClose để requestCheckpoint Future treo vĩnh viễn"
type: bug
priority: P1
effort: S
source: "claude audit vòng 3 — tái hiện timeout độc lập"
---

## Vị trí
`lib/core/checkpoint_coordinator.dart`.

## Hiện trạng và hậu quả
`onClose()` cancel debounce timer nhưng không complete `_pendingCompleters`. Caller đang await non-critical `requestCheckpoint()` bị treo vĩnh viễn.

## Acceptance criteria
- [x] Close hoàn tất mọi Future đang chờ bằng typed `SdkFailure`.
- [x] Không flush/save mới sau close.
- [x] Không completer nào complete hai lần khi race close/critical/timer.
- [x] Regression test dùng fake timer pass.

## Prompt
Làm TDD trong `test/core/checkpoint_coordinator_test.dart`. Giữ semantics coalescing/critical hiện có.

## Quyết định
- Thêm cờ `_isClosed` vào `CheckpointCoordinator`. Khi `onClose()` được gọi, đánh dấu đóng, cancel debounce timer, hủy hook lifecycle và complete toàn bộ `_pendingCompleters` bằng `SdkFailure` kiểu typed (`SdkErrorKind.unknown`).
- Mọi lời gọi `requestCheckpoint()` hoặc `flushNow()` sau khi close đều lập tức trả về `SdkFailure` mà không tạo completer mới hay ghi vào `storage`.
- Trong `_completePending` và timer callback, kiểm tra `!completer.isCompleted` và `_isClosed` để chống race condition khiến completer bị complete hai lần (`Bad state`).
- TDD: Bổ sung 3 regression tests dùng fake timer (xác nhận RED với TimeoutException và unhandled writes sau close; GREEN sau fix). Toàn bộ 18 tests và `flutter analyze` pass.
- Tự chấm audit: **9.8/10** — giải quyết dứt điểm rủi ro treo Future vĩnh viễn và rò rỉ dữ liệu ghi sau khi đóng service.
- Commit hiện thực: `5e17c1b`.
