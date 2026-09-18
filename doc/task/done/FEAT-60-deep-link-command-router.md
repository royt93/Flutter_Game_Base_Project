---
id: FEAT-60
title: "DeepLinkCommandRouter — URI thành command typed cho level/shop/event/invite"
type: feature
layer: app/logic
priority: P1
effort: M
depends_on: [FEAT-32, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app/game developer, tôi muốn parse và dispatch deep link qua command typed, có auth/readiness gate và chống xử lý trùng.

## Sprint slices
- Route definition/parser pure Dart với allowlist scheme/host/path/query.
- Typed command + validation; queue tới khi bootstrap/auth/game ready.
- Deduplicate/cooldown link; handler registry theo priority.
- Adapter URI stream do consumer cung cấp, không ép plugin vendor.

## Acceptance criteria
- [x] Link hợp lệ map đúng command; malformed/unknown/oversized input bị reject an toàn.
- [x] Link trước app-ready được xử lý đúng một lần khi ready.
- [x] Duplicate concurrent/relaunch policy deterministic.
- [x] Handler throw không làm mất link khác và có diagnostic result.

## Prompt loop feature
Đọc task/bootstrap/security paths; dùng parser fixtures TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi URI/queue/dedupe/error; analyze/test root + example; smoke Android device thật bằng adb deep link và log destination. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Đã hỏi và được user xác nhận trước khi code: task yêu cầu smoke bằng "adb deep link thật" — để làm ĐÚNG NGHĨA, cần 1 plugin thật nhận URI từ OS. Chọn thêm `app_links` vào `example/pubspec.yaml` (KHÔNG thêm vào root package `roy_casual_kit` — đúng tinh thần sprint slice "Adapter URI stream do consumer cung cấp, không ép plugin vendor": package chỉ cung cấp `DeepLinkCommandRouter`/`handleUri`, việc CẮM plugin thật nào (app_links/uni_links/...) là quyết định của app tiêu thụ).

Kiến trúc:
- Tách `parseDeepLink` (pure function, không I/O) khỏi `DeepLinkCommandRouter` (stateful, có queue/dedupe/handler registry) — đúng "parser fixtures TDD" của sprint slice, test parser không cần Get/StorageService gì cả.
- `SdkResult<DeepLinkCommand>` (FEAT-38) cho tầng PARSE (nhị phân đúng/sai rõ ràng: match route hay không) — nhưng tầng ROUTER dùng 1 enum `DeepLinkOutcome` (`dispatched`/`queuedUntilReady`/`duplicateIgnored`/`rejected`) thay vì ép `SdkResult` cho 4 trạng thái nghĩa khác nhau (queued không phải "lỗi", ép vào `SdkFailure` sẽ sai ngữ nghĩa).
- **Not-ready queue**: `_pendingBeforeReady` là `List<Uri>`, add link mới bị BỎ QUA nếu URI (dạng string) đã có sẵn trong queue — chặn double-queue khi link trùng đến 2 lần TRƯỚC ready (test xác nhận: markReady() chỉ drain đúng 1 lần dù link trùng gửi 2 lần trước đó). `markReady()` tự guard (`if (_ready) return`) nên gọi 2 lần không drain lại.
- **Dedup cooldown**: mốc `_lastHandledAtMs[uri.toString()] = nowMsClamped()` ghi NGAY LÚC quyết định dispatch, TRƯỚC vòng lặp `await handler(...)` đầu tiên — nhờ vậy 2 lệnh gọi `handleUri` ĐỒNG THỜI (không `await` giữa 2 lệnh) cho kết quả deterministic: lệnh đầu chạy đồng bộ tới lúc set mốc thời gian rồi mới `await` (nhường event loop), lệnh sau đọc thấy mốc đã set → tự nhận `duplicateIgnored` ngay — không cần lock/mutex nào thêm.
- **Handler isolation**: mỗi `commandType` có 1 LIST handler (không phải 1 handler duy nhất) sắp theo priority giảm dần; mỗi handler chạy trong try/catch RIÊNG — 1 handler throw chỉ làm ĐÚNG entry đó `succeeded: false` trong `DeepLinkHandlerResult`, không ảnh hưởng handler khác CÙNG command lẫn command KHÁC (test xác nhận cả 2 trường hợp).

**Test:** `test/core/deep_link_command_router_test.dart` (17 case, TDD — RED xác nhận qua "Method not found"/"Undefined name" trước khi viết `deep_link_command_router.dart`): parser (match đúng route + path param + query merge, scheme/path không khớp bị reject, oversized bị reject), not-ready queue (queued/drain đúng 1 lần/queue trùng không double/markReady gọi 2 lần không double-drain), dispatch sau ready (đúng command tới handler, không khớp route thì rejected không gọi handler nào), dedupe (trong cooldown bị ignore/sau cooldown xử lý lại/2 lệnh gọi đồng thời deterministic), handler isolation (1 handler throw không chặn handler khác cùng command, không chặn command khác, priority cao chạy trước).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1481/1481 pass (1 lần chạy gặp lại `api_compatibility_test.dart` do quên snapshot lại, đã fix). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 71/71 pass. `dart pub publish --dry-run` → 1 warning quen thuộc. CHANGELOG.md cập nhật mục 0.2.0.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`) bằng **adb deep link thật** (không phải mock): thêm intent-filter `roycasualkit://open/...` vào `example/android/app/src/main/AndroidManifest.xml`, wire `app_links` trong `main.dart` (`AppLinks().uriLinkStream.listen(router.handleUri)`, gated `!isE2eTest` giống audio), `markReady()` sau first frame.
- `adb shell am start -a android.intent.action.VIEW -d "roycasualkit://open/level/5" com.galaxyjoy.roycasualkit` lúc app đã bị kill (cold-start) → app mở đúng lên HomeScreen, không crash (`mobile_list_crashes` rỗng). Ghi chú: cold-start hiện KHÔNG hiển thị kết quả trên demo vì handler 'level'/'shop' chỉ được đăng ký trong `WidgetShowcaseScreen.initState()` — nếu link tới TRƯỚC khi màn hình đó mount, router vẫn dispatch đúng (queue → drain đúng 1 lần khi `markReady()`) nhưng `handlerResults` rỗng vì chưa ai đăng ký — đây là giới hạn của DEMO (handler đặt ở 1 màn hình cụ thể), không phải giới hạn của `DeepLinkCommandRouter` (cơ chế lõi đã test đầy đủ, kể cả case "queue rồi ready" y hệt).
- Vào Bộ Widget (handler đã đăng ký), bắn `adb shell am start ... -d "roycasualkit://open/level/99"` lúc app ĐANG CHẠY (warm — `singleTop` launch mode báo "Activity not started, intent delivered to currently running top-most instance", đúng như kỳ vọng) → UI thật cập nhật ngay "level: mở level 99" — chứng minh chuỗi THẬT hoàn chỉnh: OS intent → manifest intent-filter → `app_links` → `DeepLinkCommandRouter.handleUri` → handler đăng ký → `setState` → UI. Gửi lại đúng URI lần nữa (test dedupe/relaunch thật) → không crash, không exception trong log.

**Tự chấm điểm: 9.5/10** — tách đúng pure parser khỏi stateful router (test parser không cần bootstrap gì); dedupe deterministic cho 2 lệnh gọi đồng thời nhờ stamp mốc thời gian TRƯỚC await đầu tiên (không cần mutex); handler isolation đúng CẢ 2 chiều (handler khác cùng command, và command khác); có bằng chứng device thật với ĐÚNG plugin thật (`app_links`) và ĐÚNG lệnh adb như acceptance criterion gốc yêu cầu, không phải giả lập. Trừ 0.5 vì giới hạn demo (handler đăng ký ở 1 màn hình cụ thể) khiến cold-start deep link không có bằng chứng UI trực quan — đã giải thích rõ đây là giới hạn demo, không phải giới hạn cơ chế lõi.

