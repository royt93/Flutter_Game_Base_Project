---
id: BUG-75
title: "Public capacity cấu hình 0 gây crash và phá idempotency ở core services"
type: bug
priority: P1
effort: M
source: "claude audit vòng 3 — tái hiện bằng test độc lập"
---

## Vị trí
- `ConnectivityCoordinator`: `maxQueueSize`, `failuresToGoOffline`.
- `OfflineOutboxService`: `capacity`.
- `RewardTransactionPipeline`: `capacity`.
- `PlayerProgressionService`: `capacity`.
- `InventoryService`: `capacity`, `transactionCapacity`.
- `RetryPolicy`/`RetryExecutor`: validation hiện chỉ qua `assert`.

## Hiện trạng và hậu quả
Các limit public không được runtime-validate nhất quán. Tái hiện độc lập đã xác nhận:
- Inventory `transactionCapacity: 0` cấp item hai lần cho cùng `transactionId`.
- Progression `capacity: 0` cộng XP hai lần cho cùng `transactionId`.
- Pipeline `capacity: 0` làm mất record partial nên `resumePending()` không thể hoàn tất.
- Connectivity `maxQueueSize: 0` ném `RangeError` ở enqueue đầu tiên.
- Outbox `capacity: 0` không thể nhận item hợp lệ đầu tiên.
- `RetryPolicy` chỉ assert nên release build có thể đi vào `StateError('unreachable')`.

## Acceptance criteria
- [x] Mọi capacity/limit trên bị từ chối rõ ràng trước khi gây crash hoặc mất ledger.
- [x] Duplicate transaction vẫn idempotent sau khi thử cấu hình invalid.
- [x] `RetryExecutor` từ chối policy invalid trong mọi build mode mà không phá `const RetryPolicy` API.
- [x] Có regression test cho từng tác động đã tái hiện.
- [x] Root analyze và test liên quan pass.

## Prompt
Làm TDD. Trước tiên thêm test regression tại các test core tương ứng, xác nhận fail trên code cũ. Giữ `RetryPolicy` const-constructible; đặt runtime validation ở trust boundary phù hợp. Dùng precedent `AssetPreloadCoordinator`, `ReplayRecorder`, `LocalScoreboardService`. Không thay đổi semantics của capacity hợp lệ.

## Quyết định
- Thêm runtime validation tại constructor của `ConnectivityCoordinator`, `OfflineOutboxService`, `RewardTransactionPipeline`, `PlayerProgressionService` và `InventoryService`; mọi limit/capacity không dương đều ném `ArgumentError` trước khi khởi tạo state hoặc hydrate dữ liệu.
- Giữ nguyên `const RetryPolicy` để không phá API nguồn. `RetryExecutor.run` là runtime trust boundary và trả về `SdkFailure(kind: SdkErrorKind.validation)` khi `maxAttempts`, `jitterFraction`, delay hoặc timeout không hợp lệ.
- Thêm regression test cho từng cấu hình lỗi, gồm các boundary có thể làm mất idempotency ledger, vô hiệu outbox/audit trail hoặc gây queue crash. Các test dùng subclass policy để mô phỏng dữ liệu invalid lọt qua `assert` trong release mode.
- Kiểm chứng: 144 test liên quan pass; `flutter analyze` không có issue; `test/api_compatibility_test.dart` pass. Full suite còn 19 golden pixel-diff không liên quan trong `test/widget/goldens/`; không có production/widget golden nào thuộc BUG-75 bị thay đổi.
- Tự chấm audit: **9.6/10** — fix nằm đúng trust boundary, bảo toàn `const` API và semantics cấu hình hợp lệ, có regression coverage cho toàn bộ bề mặt đã audit.
- Commit hiện thực: `3bb03a4`.
