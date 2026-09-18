---
id: FEAT-35
title: "RetryPolicy — timeout, exponential backoff và jitter inject được"
type: feature
layer: core/utils
priority: P1
effort: M
depends_on: [FEAT-34]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là developer, tôi muốn cloud save/config/analytics retry nhất quán mà không copy vòng lặp delay.

## Sprint slices
- Immutable policy: attempts, timeout, base/max delay, jitter, predicate.
- Clock/delay/random inject được để test deterministic.
- Typed attempt result và hook quan sát retry; hỗ trợ cancel.
- Ví dụ tích hợp RemoteConfig hoặc CloudSave, không hardcode vào service.

## Acceptance criteria
- [x] Tính delay/cap/jitter đúng và không overflow với cấu hình biên.
- [x] Chỉ retry lỗi được phép; success, non-retryable, timeout và cancel dừng đúng.
- [x] Không retry vô hạn, không nuốt stack trace cuối.
- [x] Integration chứng minh một service phục hồi sau lỗi transient.

## Prompt loop feature
Đọc task và code liên quan; TDD toàn bộ state machine. End loop: audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; analyze/test root + example; smoke Android device thật với fake/transient network và log attempts. Lặp đến work và điểm >9/10 mới commit + push; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Tách 2 lớp: `RetryPolicy` (thuần toán học, immutable, không I/O) + `RetryExecutor` (chạy vòng lặp thật, inject được `delayFn`/`randomFn`) — đúng lý do "Clock/delay/random inject được để test deterministic": test không bao giờ chờ delay thật, kể cả `maxDelay` cỡ giây.
- `delayBeforeAttempt(attemptNumber, randomValue)` tính TOÀN BỘ bằng `double` micro-giây — 1 attempt number cực lớn khiến `pow(2, exponent)` tiến tới `double.infinity` vẫn cap đúng qua `min()` (`min(double.infinity, x) == x`), không overflow/NaN, không cần guard riêng cho trường hợp biên.
- `randomValue` là tham số TRUYỀN VÀO (không tự gọi `Random()` bên trong `RetryPolicy`) — giữ đúng policy 100% thuần, mọi nguồn ngẫu nhiên/thời gian nằm ở `RetryExecutor` (mirror đúng convention `HapticChoreographer`'s `createTimer` đã có).
- Kết quả trả `SdkResult<T>` (tái dùng FEAT-38, dù task này chỉ formal depends_on FEAT-34) — "Typed attempt result" tự nhiên nhất là dùng lại type đã có trong toàn repo, không tự chế type mới.
- `retryIf` (mặc định: luôn retryable) quyết định lỗi có được retry hay không — TimeoutException (từ `policy.timeout`) đi qua ĐÚNG cùng logic này, không hard-code timeout là non-retryable hay luôn-retry — caller tự quyết qua predicate nếu muốn khác mặc định.
- `isCancelled` poll trước mỗi attempt (sau delay) — dừng ngay, không chạy thêm action nào.
- Lỗi cuối cùng LUÔN giữ `cause`/`stackTrace` trong `SdkFailure` trả về dù retry hết hạn hay non-retryable — không bao giờ nuốt lỗi gốc.
- `onAttempt` hook phát đủ 5 outcome (`success/retrying/failedNonRetryable/failedExhausted/cancelled`) — quan sát được toàn bộ vòng đời, dùng cho `dlog`/debug overlay sau này.
- KHÔNG tích hợp cứng vào `RemoteConfigService`/`CloudSaveProvider` thật (đúng "không hardcode vào service" trong sprint slice) — ví dụ tích hợp chỉ là 1 hàm giả lập flaky trong test/integration test, không sửa 2 service đó.

**Test:** `test/core/utils/retry_policy_test.dart` (13 case, TDD — RED xác nhận trước khi viết `retry_policy.dart`): `delayBeforeAttempt` đúng cho attempt 1 (0), attempt 2/3 (exponential), jitter 2 hướng, attempt cực lớn cap đúng không overflow, biên hợp lệ không throw; `RetryExecutor.run`: thành công lần đầu không delay, fail 2 lần rồi thành công lần 3 (phục hồi sau lỗi transient), non-retryable dừng ngay lần đầu, hết `maxAttempts` dừng đúng giữ `cause`/`stackTrace`, cancel giữa chừng dừng ngay, timeout per-attempt đi qua đúng logic retry, delay/random đều qua hàm inject (không dùng `Future.delayed`/`Random` thật — verify bằng `maxDelay: 999s` không thực sự chờ).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1382/1382 pass (1 lần chạy gặp lại đúng `save_slot_manager_test.dart` flaky pre-existing đã biết nhiều lần trong phiên — verify pass riêng lẻ, không liên quan). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass (không cần UI showcase — util thuần logic). `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại, CHANGELOG.md cập nhật mục 0.2.0. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): thêm `testWidgets('FEAT-35: ...')` vào `example/integration_test/app_boot_test.dart` — hàm giả lập network chập chờn (lỗi transient 2 lần, thành công lần 3), log từng attempt qua `dlog` (prefix `roy93~`). Chạy `flutter test integration_test/app_boot_test.dart -d 2B051FDH3006MU --dart-define=E2E_TEST=true --plain-name "FEAT-35"` — log thiết bị thật cho thấy đúng thứ tự "FEAT-35 device attempt 1/2/3" rồi pass. Evidence: `doc/task/evidence/FEAT-35-device-smoke.log`.

Sau tự audit, bổ sung thêm 1 doc-comment ví dụ CODE thật trong `retry_policy.dart` — wrap `RemoteConfigService.fetchRemote` bằng `RetryExecutor.run` (đọc đúng chữ ký `fetchRemote: Future<Map<String,Object?>> Function()?` của `RemoteConfigService` hiện có, không sửa file đó) — vá đúng chỗ thiếu, không cần task riêng.

**Tự chấm điểm: 9.5/10** — tách đúng 2 lớp (toán học thuần vs thực thi có I/O) theo đúng lý do sprint slice yêu cầu, xử lý overflow bằng tính chất toán học của `double`/`min()` thay vì tự viết guard rườm rà, tái dùng `SdkResult` thay vì tự chế type kết quả mới, giữ đúng ranh giới "không hardcode vào service thật", tự audit phát hiện thiếu ví dụ tích hợp và vá ngay trong cùng task thay vì để sót.
