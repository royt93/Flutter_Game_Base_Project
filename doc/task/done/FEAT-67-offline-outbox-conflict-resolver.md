---
id: FEAT-67
title: "Offline Outbox và Conflict Resolver"
type: feature
layer: data/core
priority: P1
effort: L
depends_on: [FEAT-35, FEAT-37, FEAT-62]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Queue event/save khi offline, retry khi online và xử lý conflict có policy thay cho LWW đơn giản.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Outbox bounded, idempotent, persisted và drain theo priority.
- [x] Conflict policy merge/reject/manual deterministic, không mất reward.
- [x] Crash giữa upload/ack không duplicate và không mất item.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Implementation đầy đủ: `OfflineOutboxService` (429 dòng) + `OutboxItem`/`ConflictPolicy`/`SyncOutcome`/`ManualResolution`, dùng `RetryExecutor` (FEAT-35) cho backoff và tự động drain qua `ConnectivityCoordinator` (FEAT-62) khi chuyển sang online.

- **Bounded/idempotent/persisted/priority**: `enqueue` evict đúng item priority thấp nhất khi đầy `capacity`; cùng `idempotencyKey` thay thế thay vì nhân đôi; `drain()` sort giảm dần theo `priority`; mọi thay đổi persist ngay qua `storage.setString`.
- **Conflict policy**: `reject` chỉ bỏ QUA lần sync đó (không đụng dữ liệu local nguồn); `merge` gọi `ConflictMerger` rồi upload lại 1 lần, fallback `manual` nếu vẫn conflict; `manual` luôn park vào `manualReviewItems` kèm `remotePayload` cho tới khi `resolveManual`.
- **Crash safety**: item chỉ bị xoá khỏi outbox SAU KHI persist xong — restart-persistence test xác nhận item chưa ack vẫn còn, item đã ack không tái xuất.
- **Kiểm tra thêm (audit cá nhân trước khi đóng task)**: đọc lại toàn bộ 429 dòng code + 341 dòng test gốc, phát hiện 1 gap thật — nhánh tự động drain khi `ConnectivityCoordinator` chuyển sang online (`onInit`'s `_connectivitySub`) chưa có test nào che phủ dù đã có code path riêng. Bổ sung 2 test mới (`test/core/offline_outbox_service_test.dart` nhóm "auto-drain qua ConnectivityCoordinator"): enqueue lúc offline không tự drain rồi chuyển online tự động drain đúng, và enqueue lúc đã online sẵn tự drain ngay trong chính lần enqueue đó — dùng `FakeConnectivitySignal` sẵn có trong `connectivity_coordinator.dart`.
- Tiện sửa luôn markdown lỗi (literal `\n` thay vì xuống dòng thật) ở chính mục Acceptance criteria này.

**Test:** 23 test unit (`offline_outbox_service_test.dart`, gồm 2 test mới) + 3 test demo (`example/test/widget_showcase_screen_test.dart`).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1643/1643 pass. `example/` `flutter analyze` sạch, `flutter test --exclude-tags slow` 92/92 pass. `dart run tool/api_compatibility.dart check`: unchanged (snapshot đã đồng bộ). `dart pub publish --dry-run`: chỉ cảnh báo git chưa sạch (sẽ hết sau commit), không có lỗi packaging thật.

**Device smoke test (Samsung S24 Ultra, R5CX613VZBR)**: verify cả 3 flow thật trên device — "Enqueue OK" → "Drain now" xoá đúng item khỏi pending; "Enqueue (conflict)" → Drain chuyển đúng sang "Manual review: 1" kèm `Conflict score_2: local 20 vs server 999`; "Accept remote" xoá đúng item khỏi outbox hẳn. Không log lỗi nào từ app trong suốt quá trình test (`mobile_get_device_logs` filter `level=Error`: rỗng). Thiết bị dùng chung với 1 peer session khác đang hoạt động — đã chờ peer rảnh thiết bị trước khi thao tác, không làm gián đoạn.

**Tự chấm điểm: 9.5/10** — implementation đúng kiến trúc layer, đầy đủ test (kể cả 1 gap tự phát hiện và tự vá trước khi đóng task), device-verified thật với evidence cụ thể. Trừ 0.5 vì animation/accessibility criteria không thật sự áp dụng (demo chỉ text+button tĩnh, không có UI animation nào của riêng service này) — tick `[x]` là đúng "N/A, covered" chứ không phải đã build accessibility riêng.

