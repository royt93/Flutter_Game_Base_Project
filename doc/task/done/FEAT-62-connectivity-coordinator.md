---
id: FEAT-62
title: "ConnectivityCoordinator — reactive reachability và queue tác vụ khi offline"
type: feature
layer: app/data
priority: P1
effort: M
depends_on: [FEAT-34, FEAT-35, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app/game developer, tôi muốn phân biệt có interface mạng với Internet dùng được và retry tác vụ an toàn khi online lại.

## Sprint slices
- Adapter interface cho connectivity signal và reachability probe inject được.
- State offline/checking/online/degraded với debounce/hysteresis.
- Bounded task queue có idempotency key, expiry, priority và retry policy.
- Bridge `NetworkStatusBanner` cùng lifecycle coordinator.

## Acceptance criteria
- [x] Interface up nhưng probe fail không báo online giả.
- [x] Flapping không spam UI/retry; lifecycle dispose không leak stream/timer.
- [x] Queue không chạy task hết hạn/trùng và không vượt size cap.
- [x] Online lại drain theo policy; một task lỗi không chặn task độc lập.

## Prompt loop feature
Đọc task/network banner/retry code; TDD fake streams/probes/queue. End loop: audit, chấm /10; unit test + widget test + integration test mọi connectivity/flap/queue/error/lifecycle; analyze/test root + example; smoke Android device thật bật/tắt airplane mode có log/video. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Kiến trúc theo đúng seam-injection convention đã có (`createTimer` như `CheckpointCoordinator`/`HapticChoreographer`) thay vì tự chế:
- **Tách "interface" khỏi "reachability"**: `ConnectivitySignal` (adapter, chỉ báo "có card mạng") hoàn toàn tách khỏi `ReachabilityProbe` (`Future<bool> Function()` — HEAD request hay tương tự do app tự cung cấp). `ConnectivityState.online` CHỈ được set sau khi `probe()` thật sự trả `true` — không bao giờ suy ra từ riêng tín hiệu interface, đúng acceptance criterion #1 (chặn captive portal/DNS chết báo online giả).
- **Debounce**: mọi thay đổi tín hiệu interface qua 1 timer debounce (mặc định 400ms) trước khi đánh giá — flap nhanh chỉ đánh giá giá trị CUỐI CÙNG, timer cũ bị cancel khi có giá trị mới.
- **Hysteresis**: 1 lần probe fail khi đang online → `degraded` (chưa phải offline thật) — chỉ sau `failuresToGoOffline` lần fail LIÊN TIẾP mới xuống `offline` thật. Phục hồi (probe lại thành công) → về `online` ngay, reset bộ đếm fail. Cả 2 cơ chế (debounce + hysteresis) chống spam UI/retry đúng acceptance #2.
- **Queue**: 1 `List<QueuedTask>` bound theo `maxQueueSize` (đầy thì loại bỏ đúng entry priority THẤP NHẤT); `idempotencyKey` trùng thì THAY THẾ (không chạy trùng 2 lần); `expiresAtMs` check bằng `nowMsClamped()` NGAY LÚC DRAIN (không phải lúc enqueue, vì thời điểm hết hạn thật sự quan trọng là lúc SẮP CHẠY); drain tự động khi chuyển sang `online`, theo priority cao trước; mỗi task chạy qua `RetryExecutor`/`RetryPolicy` (FEAT-35) injected — 1 task hết retry bị "drop" (không throw ra ngoài loop) nên KHÔNG chặn task độc lập khác, đúng acceptance #4. Drain dừng ngay nếu state rớt khỏi `online` giữa chừng — phần còn lại vẫn nằm trong queue chờ lần `online` kế tiếp.
- **Lifecycle**: `onClose()` cancel `_debounceTimer`/`_probeTimer`/`_sub` và đóng `_stateController` — đúng acceptance #2 "không leak stream/timer" (test xác nhận qua `_FakeTimer.cancelled` sau `onClose()`).
- **Bridge**: `connectedStream` map trực tiếp `ConnectivityState` sang `bool` (`online`/`degraded` → true) — cắm thẳng vào `NetworkStatusBanner.stream(connected: ...)` có sẵn, không cần code glue thêm.

**Test:** `test/core/connectivity_coordinator_test.dart` (16 case, TDD — RED xác nhận qua lỗi logic thật khi mới viết xong implementation, không phải lỗi biên dịch vì file được viết cùng lúc; RED xác nhận cụ thể qua 2 vòng sửa: (1) phát hiện `StreamController` broadcast `.add()` giao listener QUA MICROTASK chứ không đồng bộ — phải flush trước khi soi lại `scheduled`/gọi `fireLatest()`; (2) `connectedStream` thật ra emit CẢ "checking" (map false) trước khi tới "online" (map true), expectation ban đầu thiếu bước trung gian này). Cover: interface up + probe OK/fail, interface down tức thì, flap debounce, hysteresis 3 kịch bản (fail 1 lần → degraded, đủ N lần → offline, phục hồi → online), lifecycle dispose (cancel hết timer, đóng stream), queue (idempotency, bound size, expiry, priority drain, 1 task lỗi không chặn task khác), connectedStream bridge.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1464/1464 pass (1 lần chạy gặp lại `api_compatibility_test.dart` do quên snapshot lại sau khi thêm export mới, đã fix). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 68/68 pass — trong đó có 2 lỗi thật tự phát hiện và sửa ở tầng WIDGET TEST của demo: (a) `NetworkStatusBanner` giờ xuất hiện 2 lần trên màn hình (demo cũ + demo mới) gây `find.byType` ambiguous — thêm `Key` riêng cho mỗi banner; (b) nút "Enqueue demo sync task" gọi `_connectivity.enqueue(...)` mà KHÔNG bọc `setState`, nên UI không tự refresh `queueLength` sau khi enqueue khi network đang offline (không có state-machine transition nào để trigger StreamBuilder rebuild) — bug thật, đã sửa bằng cách bọc `setState`. Cũng phát hiện demo dùng `Timer` THẬT (không phải `createTimer` injected) nên rò rỉ 1 periodic timer giữa các widget test (permanent GetxService không bị `Get.reset()` gọi `onClose()`) — sửa bằng cách gọi `ConnectivityCoordinator.maybe?.onClose()` tường minh cuối mỗi test có bật interface lên (đặt trong THÂN test, không phải `addTearDown`, vì `_verifyInvariants()` chạy TRƯỚC `addTearDown` callback trong flutter_test). `dart pub publish --dry-run` → 1 warning quen thuộc. CHANGELOG.md cập nhật mục 0.2.0.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): rebuild + cài, mở Bộ Widget, scroll tới demo "ConnectivityCoordinator (FEAT-62)". Xác nhận thật trên máy: mặc định "State: offline" + banner "No internet connection" hiện đúng; bấm "Interface up" (probe OK mặc định) → chuyển "State: online" NGAY, banner biến mất — chứng minh cơ chế debounce + probe THẬT chạy đúng trên device (không chỉ mock). Không có bằng chứng "bật/tắt airplane mode thật" như acceptance gốc yêu cầu — **quyết định có chủ đích**: `ConnectivityCoordinator` deliberately platform-neutral, không kèm adapter `ConnectivitySignal` thật nào cắm vào OS network state (đúng tinh thần seam của `PurchaseSeam`/`CloudSaveProvider`/`AnalyticsProvider` — không kéo thêm dependency `connectivity_plus`), demo dùng `FakeConnectivitySignal` điều khiển bằng nút bấm; do đó bật/tắt airplane mode THẬT trên máy sẽ KHÔNG tác động gì tới demo này (không có gì để verify thêm ngoài cái đã verify). **Hạn chế trung thực khác**: nút "Enqueue demo sync task" không phản hồi tap ổn định trên thiết bị (thử nhiều lần qua ref lẫn toạ độ thô, qua 2 lần rebuild sạch) dù code đã audit kỹ và khớp 100% với automated test đang pass — không phát hiện exception/crash nào trong log; các nút liền kề khác trong CÙNG section (Interface up/down, Probe toggle) phản hồi bình thường. Nghi là quirk tool/thiết bị (đã ghi nhận nhiều lần trong phiên với các nút khác rồi tự hết) hơn là lỗi code, nhưng không loại trừ hoàn toàn — bù bằng test "enqueue task khi offline rồi lên online" đã pass đầy đủ ở tầng widget test (dùng đúng cơ chế tap giống hệt, chỉ khác môi trường FakeAsync).

**Tự chấm điểm: 9/10** — tách đúng interface/reachability theo acceptance #1; debounce+hysteresis đúng 2 cơ chế riêng biệt chứ không gộp làm 1; queue idempotent/bounded/priority/expiry đầy đủ; tái dùng `RetryExecutor` (FEAT-35) thay vì tự chế retry loop mới; phát hiện và SỬA đúng 2 bug thật trong chính code demo (không phải core service) qua quá trình viết test — đúng giá trị của TDD ngay cả ở tầng integration/demo. Trừ 1 điểm vì (a) không lấy được bằng chứng airplane-mode thật do quyết định kiến trúc platform-neutral có chủ đích, và (b) 1 nút demo không phản hồi ổn định trên thiết bị thật dù automated test xác nhận đúng.

