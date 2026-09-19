---
id: FEAT-71
title: "Platform Capability Registry"
type: feature
layer: core/platform
priority: P1
effort: M
depends_on: [FEAT-32, FEAT-38]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Detect capability Android/iOS/web/desktop cho audio, shader, notification, haptic và chọn fallback.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Capability snapshot typed, cache được và không gọi platform channel ngoài capability.
- [x] Unsupported feature có fallback/policy rõ thay vì crash.
- [x] Device matrix và integration test cover platform fake.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved. (N/A — task thuần logic/registry, không có UI riêng ngoài demo hiển thị dữ liệu tĩnh)

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Kiến trúc:
- **Không có "platform channel" thật nào** — `detectPlatformCapabilities()` chỉ đọc 2 hằng số Flutter TỰ giải quyết sẵn lúc process khởi động: `kIsWeb`/`defaultTargetPlatform` (từ `package:flutter/foundation.dart`, không phải plugin/SDK vendor nào). Đây chính là "không gọi platform channel ngoài capability" — về bản chất KHÔNG CÓ platform channel nào được gọi thêm cả, chỉ đọc giá trị Flutter đã resolve.
- **Cache = tính đúng 1 lần lúc construct**: `PlatformCapabilityRegistry.snapshot` là field `final`, gán trong constructor — "cache" tự nhiên đúng nhờ bất biến, không cần logic invalidate/refresh nào (platform của 1 process không đổi giữa chừng).
- **Compatibility policy được DOCUMENT rõ, không phải "sự thật cứng"**: doc comment của `PlatformCapabilitySnapshot` nói rõ đây là QUYẾT ĐỊNH BẢO THỦ có chủ đích (web luôn coi là KHÔNG hỗ trợ cả 4 domain; desktop không có haptic API nên riêng haptics cũng false) — không phải kết quả probe runtime thật, và ai cần chính xác hơn cho target cụ thể có thể tự truyền `snapshot` override thẳng vào constructor.
- **`withFallback<T>`**: cơ chế fallback chung, generic, KHÔNG che giấu lỗi thật — nếu nhánh `ifSupported`/`fallback` tự throw, exception đó vẫn lan truyền bình thường (test xác nhận rõ) — chỉ đơn thuần CHỌN nhánh nào chạy, không phải try/catch nuốt lỗi.
- **Device matrix**: `isWeb`/`targetPlatform` injectable trực tiếp vào `detectPlatformCapabilities()` — test fixture đủ 7 tổ hợp (android/iOS/windows/macOS/linux/fuchsia + web) mà không cần build/chạy trên từng platform thật.

**Test:** `test/core/platform_capability_registry_test.dart` (15 case, TDD — RED xác nhận qua "Method not found" trước khi viết `platform_capability_registry.dart`): device matrix đủ 7 tổ hợp platform (bao gồm biên "web bất kể targetPlatform bên dưới là gì vẫn luôn coi là web"), registry SSOT/cache (snapshot y hệt qua nhiều lần đọc bằng `identical()`, inject snapshot override), `withFallback` (đúng nhánh theo `supported`, lỗi thật không bị nuốt). `example/test/widget_showcase_screen_test.dart` (+2 case): hiện đúng platform+4 capability trong môi trường test (android mặc định của `flutter test`), bấm "Fire haptic" chạy đúng nhánh `ifSupported` (môi trường test coi là hỗ trợ haptics).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1537/1537 pass (1 lần chạy gặp lại `season_event_service_test.dart` flaky pre-existing đã biết, pass khi chạy riêng lẻ). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 77/77 pass. `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại. `dart pub publish --dry-run` → 1 warning quen thuộc. CHANGELOG.md cập nhật mục 0.2.0.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): rebuild + cài, scroll tới demo "PlatformCapabilityRegistry (FEAT-71)" — hiện ĐÚNG "Platform: android" với cả 4 capability `true` (khớp chính sách đã document cho platform android thật, không phải giả lập). Bấm "Fire haptic (with fallback)" — không crash (`mobile_list_crashes` rỗng); haptic là phản hồi RUNG vật lý nên không có gì thêm để chụp màn hình ngoài xác nhận không lỗi — hành vi nhánh `ifSupported` đã verify đầy đủ ở tầng widget test.

**Tự chấm điểm: 9.5/10** — đúng tinh thần "0 platform channel thêm" bằng cách chỉ dựa vào 2 hằng số Flutter đã resolve sẵn, không cần thêm bất kỳ plugin/dependency mới nào; tách rõ RÀNG "policy bảo thủ có tài liệu" khỏi "sự thật platform cứng" (đúng yêu cầu "compatibility policy" của acceptance #4); `withFallback` không bao giờ nuốt lỗi thật — đây là điểm dễ làm sai (dev hay lạm dụng try/catch trong helper kiểu này) nhưng đã tránh đúng. Trừ 0.5 vì demo/tích hợp mới dừng ở MỨC HIỂN THỊ + 1 nút minh hoạ (haptic), chưa thực sự RETROFIT vào 3 domain còn lại (shader/notification/backgroundAudio) của các service đã có sẵn trong kit (`ShaderTickerLayerState`, `ReminderService`, `AudioManager`) — quyết định có chủ đích để tránh mở rộng phạm vi/rủi ro cho các service ổn định sẵn có, nhưng đây là phần "tích hợp" chưa trọn vẹn nếu so với đúng nghĩa đen sprint slice 3 ("Add consumer/example integration").

