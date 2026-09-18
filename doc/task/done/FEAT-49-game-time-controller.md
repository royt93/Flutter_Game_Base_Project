---
id: FEAT-49
title: "GameTimeController — pause, time-scale và deterministic tick"
type: feature
layer: game/logic
priority: P0
effort: M
depends_on: [FEAT-41, FEAT-45]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn gameplay clock riêng với wall clock để pause/slow-motion/replay không làm sai timer.

## Sprint slices
- Pure clock state elapsed/delta/scale/paused và injectable tick source.
- Clamp invalid/huge delta, fixed-step optional và deterministic advance cho test.
- Bridge Flame update loop và GetX snapshot cho Flutter countdown.
- Lifecycle/session pause ownership rõ, tránh double pause/resume.

## Acceptance criteria
- [x] Pause đóng băng elapsed; resume không cộng thời gian background.
- [x] Time scale hợp lệ, invalid input không poison state.
- [x] Cùng tick sequence/seed cho cùng simulation result.
- [x] Flame và Flutter observer thấy cùng game time không drift đáng kể.

## Prompt loop feature
Đọc task/session/RNG dependencies; TDD timeline matrix trước bridge. End loop: audit changes, chấm /10; unit test + widget test + integration test pause/scale/fixed-step/lifecycle; analyze/test root + example; smoke Android device thật với pause/background/slow-motion proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Mirror đúng cấu trúc 2 lớp `PerformanceTierService`/`FrameBudgetTracker` đã có (pure core + GetxService bridge) thay vì tự nghĩ pattern mới:
- `GameClock` (pure, không phụ thuộc Flutter/Flame/wall-clock): `advance(Duration realDelta)` — clamp delta âm về 0, clamp delta khổng lồ về `maxDeltaPerTick` (mặc định 250ms), nhân `scale`, cộng vào `elapsed`; `paused=true` làm `advance()` no-op hoàn toàn (không có khái niệm "thời gian nền cần trừ lại" vì nó chưa từng được cộng). `setScale()` từ chối NaN/Infinity/0/âm, giữ nguyên scale cũ — không có state nào bị "poison". Fixed-step optional qua accumulator (dư thời gian giữ lại cho lần `advance()` sau) — trả về số step nguyên đã đi được, phục vụ physics/replay xác định.
- `GameTimeController extends GetxService`: bọc `GameClock`, expose `elapsed` dạng `Rx<Duration>` (Obx được), `tick(double dtSeconds)` đúng chữ ký `Component.update(dt)` của Flame để 1 component gọi thẳng — Flame và Flutter widget cùng đọc 1 instance nên không có 2 đồng hồ lệch nhau cần đồng bộ.
- Pause ownership: khi truyền `session` (`GameSessionController`, FEAT-41), coordinator đọc `session.snapshot.value.phase == paused` làm NGUỒN DUY NHẤT — không tự giữ thêm flag/reason pause riêng, tránh double pause/resume giữa 2 hệ thống mà sprint slice yêu cầu. Không truyền `session` thì dùng `setPaused(bool)` standalone (đồng hồ đếm ngược không gắn game session).
- KHÔNG dùng `SeededRandomService` (FEAT-45) trực tiếp trong code — dependency này là về CHỦ ĐỀ "cùng deterministic cho replay" (RNG lẫn clock cùng phải xác định để 1 replay tái tạo đúng), không phải một lời gọi API thật; `GameClock.advance()` đã xác định 100% (không đọc bất kỳ nguồn ngẫu nhiên/wall-clock nào bên trong) nên không cần ép phụ thuộc code không cần thiết vào FEAT-45.
- KHÔNG thêm vào `RoyCasualKitModule` bootstrap — giữ đúng quyết định nhất quán với FEAT-42/FEAT-46, consumer tự khởi tạo khi cần.

**Test:** `test/core/game_time_controller_test.dart` (14 case, TDD — RED xác nhận trước khi viết `game_time_controller.dart`): `GameClock` cộng dồn theo scale, paused không cộng, resume không cộng bù thời gian nền, delta âm/khổng lồ bị clamp đúng, `setScale` từ chối input xấu giữ nguyên state, fixed-step đúng bội số + giữ số dư, chuỗi `advance()` xác định (chạy 2 lần cho cùng kết quả); `GameTimeController.tick()` cập nhật `elapsed` Rx đúng, `setScale` trả `SdkResult` đúng, không wire session dùng `setPaused` riêng, có wire session thì session là nguồn pause duy nhất (test bắt lỗi 1 lần vì dt test 0.5s/1s vượt `maxDeltaPerTick` mặc định — sửa test dùng `maxDeltaPerTick` lớn hơn cho case này, không phải bug code), `.maybe`.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1309/1309 pass (1 lần chạy gặp lại đúng `season_event_service_test.dart` flaky pre-existing đã biết từ FEAT-42/FEAT-46 — không liên quan, đã verify riêng). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 55/55 pass (task thuần logic, không cần UI showcase). `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại, CHANGELOG.md cập nhật mục 0.2.0. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): thêm `testWidgets('FEAT-49: ...')` vào `example/integration_test/app_boot_test.dart` (đúng convention, cạnh test FEAT-41 sẵn có) — wire `GameTimeController` với `GameSessionController` thật + `RoyLifecycleCoordinator` thật, `tick()` trước/trong/sau khi `didChangeAppLifecycleState(paused)`/`(resumed)`, verify elapsed đứng yên đúng lúc nền và không cộng bù khi resume. Chạy `flutter test integration_test/app_boot_test.dart -d 2B051FDH3006MU --dart-define=E2E_TEST=true --plain-name "FEAT-49"` (lọc riêng, tránh lỗi audioplayers pre-existing khi chạy cả file). Evidence: `doc/task/evidence/FEAT-49-device-smoke.log`.

**Tự chấm điểm: 9.5/10** — tái dùng đúng cấu trúc 2 lớp đã có sẵn trong repo (`PerformanceTierService`) thay vì tự nghĩ pattern mới, pause ownership giao hẳn cho `GameSessionController` (không có state cạnh tranh), toàn bộ acceptance criteria có test tương ứng, đúng convention device-smoke. Trừ 0.5 vì tự viết sai giả định ban đầu trong 1 test (dt thực tế vượt `maxDeltaPerTick` mặc định) trước khi phát hiện đó là test lỗi chứ không phải code lỗi.

Đây là task cuối trong loop 4 task (FEAT-50, FEAT-42, FEAT-46, FEAT-49) — cả 4 đã xong, đã push.
