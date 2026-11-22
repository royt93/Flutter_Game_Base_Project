---
id: BUG-136
title: "RemoteContentPack: giữ cache, history và current nhất quán khi persist lỗi"
type: bug
layer: lib/core/remote_content_pack
priority: P1
effort: M
source: "Full source audit 2026-11-21; verify history-write failure and rollback result"
---

## Bằng chứng

`_refreshFromRemote` ghi cache, mutate `_history`, rồi persist history; lỗi persist bị catch và bỏ qua, khiến `cache`, `_history` và `_current` không đồng bộ. `_activateHistoryRecord` có thể trả `SdkFailure(storage)` sau khi cache đã đổi. Hiện test failure chủ yếu kiểm cache-write, chưa bao phủ history-write failure.

- `lib/core/remote_content_pack.dart:449-473,519-541`
- `test/core/remote_content_pack_test.dart:797-832`

## Phạm vi

Đổi `withHistory` sang một versioned storage record chứa cache + history, để mỗi refresh/rollback commit bằng một key write. Migrate một chiều từ `${cacheKey}` + `${cacheKey}_history_v1`; giữ nguyên legacy keys và không đổi `withCache` format/contract. Không gộp race concurrent refresh (BUG-137).

## Acceptance criteria

- [x] Inject lỗi ghi combined record khi refresh; current/history và record sau restart giữ nguyên revision trước.
- [x] Inject lỗi ghi combined record khi rollback; kết quả `SdkFailure` không để cache/current/history ở revision khác nhau.
- [x] Migration một chiều đọc legacy cache/history, chỉ giữ cache nếu trùng verified history, ghi combined record mới và giữ nguyên legacy keys.
- [x] `withCache` giữ nguyên read/write format và behavior; không phụ thuộc record mới của `withHistory`.
- [x] Thành công refresh/rollback persist một combined record và reload đúng; dữ liệu cũ không mất.
- [x] Combined-record write fail giữ nguyên current/history và record trước; migration write fail có thể retry an toàn.
- [x] Không lộ exception ngoài hợp đồng `SdkResult`/behavior hiện có.
- [x] Unit test failure injection và restart; widget/integration không đổi UI/platform boundary nên không áp dụng, example Cookbook widget tests pass.
- [x] Audit diff và tự chấm >9/10, rubric + bằng chứng trong phần kết quả.
- [x] Chạy physical-device smoke của flow content update/rollback trong example; ghi model, OS, build/commit, bước chạy và log. Không simulator.

## Prompt loop

Đọc task, toàn bộ `RemoteContentPack`, storage persistence patterns, callers và tests. Viết regression tests trước cho legacy migration, combined-record write failure ở refresh/rollback, restart và `withCache` compatibility. Migrate `withHistory` sang một versioned record/key; chỉ commit `_current`/`_history` sau single-key write thành công, giữ legacy keys và `withCache` unchanged. Chạy unit tests liên quan, widget/integration tests nếu phạm vi chạm UI/platform, analyze và smoke trên thiết bị thật cho flow có thể quan sát. Audit lại toàn bộ diff, kiểm tra failure paths/data-loss, chấm điểm /10 theo correctness 4, tests 2, API/compatibility 2, maintainability 1, device evidence 1; lặp sửa cho tới khi >9/10 và acceptance đều đạt. Nếu không có device/fixture đủ để smoke, thiếu semantics cần owner quyết định, test đỏ, hoặc điểm <=9 thì dừng, ghi blocker, không push. Khi tất cả gates đạt và điểm >9/10, cập nhật kết quả/điểm, rồi push code theo yêu cầu owner.

## Kết quả thực hiện

- Audit / điểm: **9.2/10** — correctness 4/4, tests 2/2, API/compatibility 2/2, maintainability 0.7/1 (migration rule/cache-history matching adds logic but remains scoped), device evidence 0.5/1 (real physical apply/rollback smoke, not process-kill interruption). No public API/export change.
- Unit/widget/integration tại commit `77e5c164`: focused root test `flutter test test/core/remote_content_pack_test.dart` pass (43/43); root non-golden suite pass (4070/4070); Cookbook widget tests pass; analyzer/API gate/diff check pass. Later BUG-137 extended the same focused test file to 48 tests. Không đổi golden baselines.
- Device smoke: Samsung Galaxy S24 Ultra SM-S928B, Android 16, debug `E2E_TEST=true`, package `com.galaxyjoy.roycasualkit`; app launched via `flutter run -d R5CX613VZBR` from `example/`, opened Cookbook → Live-ops & remote content → `RemoteContentPack.withHistory — verified apply + rollback`; UI reported `applied v1 (history=1) - rollback OK to v1`. No ad SDK/request observed. This proves visible success path, not migration-on-device; migration/failure/restart edge cases are covered by tests.
- Commit/push: `77e5c16404b7cb654653149e194c5397486cfb4c` (`fix: atomically persist remote content history`), pushed; verified present on current `origin/main` at `d6ae94f2`. Later BUG-137 commit `64ccfd28` separately implements concurrent-refresh ordering.
- Rủi ro còn lại: one-way migration deliberately keeps legacy keys; downgraded app may read stale legacy state. A cache-only legacy `withHistory` record with no matching retained verified history is rejected and bundled asset is used because original HMAC cannot be recovered/reverified. Concurrent refresh ordering remains BUG-137.
