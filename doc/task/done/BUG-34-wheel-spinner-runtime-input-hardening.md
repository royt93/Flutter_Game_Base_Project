---
id: BUG-34
title: "WheelSpinner crash ở release khi index/cấu hình không hợp lệ"
type: bug
priority: P0
effort: S
source: Codex audit 2026-09-12
depends_on: []
---

## User story
Là game developer, tôi cần wheel từ chối cấu hình sai bằng lỗi rõ ràng và không crash ngẫu nhiên sau khi phát hành.

## Hiện trạng và bằng chứng
`WheelSpinnerController.spin()` nhận mọi số nguyên tại `lib/presentation/widgets/common/wheel_spinner.dart:37`; `_onSpinRequested()` dùng thẳng index tại dòng 130/140. Constructor chỉ dùng `assert` cho `segments.length >= 2` tại dòng 57, nên guard biến mất ở release. `size <= 0`, duration âm và `extraTurns < 0` cũng chưa có policy runtime.

## Scope
- Chốt contract runtime cho `segments`, `resultIndex`, `size`, `spinDuration`, `extraTurns`.
- Ưu tiên fail-fast bằng `ArgumentError`/`RangeError` tại public boundary; không silently modulo một index sai.
- Giữ hành vi cancel spin cũ và reduced motion.

## Acceptance criteria
- [x] Release/profile và debug có cùng policy; index âm hoặc `>= segments.length` không đi tới phép truy cập list.
- [x] Cấu hình hình học/thời gian không hợp lệ được chặn bằng lỗi có tên tham số.
- [x] Spin hợp lệ, spin liên tiếp và reduced motion giữ nguyên callback đúng một lần.
- [x] Unit, widget, integration và device smoke test bao phủ happy/edge/error case.

## Implementation evidence

- `WheelSpinnerController.spin()` rejects negative indexes with `RangeError` before state mutation/notification.
- `WheelSpinner.validateConfiguration()` is called from state initialization and widget updates, covering segment count, finite positive size, non-negative duration and extra turns.
- `_onSpinRequested()` rejects an index outside the supplied segment list before calculating/reading the winning segment.
- Tests added in `test/widget/common/wheel_spinner_test.dart` cover controller, all invalid configuration parameters, out-of-range index, valid animation, reduced motion and superseding spins.
- Device integration test `example/integration_test/app_boot_test.dart` (`BUG-34`) passed on Samsung SM S928B (`R5CX613VZBR`, Android 16/API 36) with `--dart-define=E2E_TEST=true`.
- `flutter analyze` and `flutter test --exclude-tags slow` passed at root and in `example/`.
- Flutter CLI does not expose `flutter test --release`; runtime validation is exercised through the non-assert state initialization/update path and device release-like APK smoke test.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng TDD. Kết thúc mỗi vòng phải: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy `flutter analyze` và `flutter test --exclude-tags slow` ở root lẫn `example/`; smoke test trên Android device thật và ghi screenshot/log làm bằng chứng. Nếu chưa đạt >9/10 thì tiếp tục sửa. Chỉ khi work đúng và điểm >9/10 mới commit + push code; sau push cập nhật `## Quyết định`, tick acceptance criteria, chuyển task sang `doc/task/done/`, commit + push lần hai.
