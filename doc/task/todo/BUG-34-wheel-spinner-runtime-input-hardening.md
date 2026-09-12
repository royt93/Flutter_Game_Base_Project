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
- [ ] Release/profile và debug có cùng policy; index âm hoặc `>= segments.length` không đi tới phép truy cập list.
- [ ] Cấu hình hình học/thời gian không hợp lệ được chặn bằng lỗi có tên tham số.
- [ ] Spin hợp lệ, spin liên tiếp và reduced motion giữ nguyên callback đúng một lần.
- [ ] Unit, widget, integration và device smoke test bao phủ happy/edge/error case.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng TDD. Kết thúc mỗi vòng phải: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy `flutter analyze` và `flutter test --exclude-tags slow` ở root lẫn `example/`; smoke test trên Android device thật và ghi screenshot/log làm bằng chứng. Nếu chưa đạt >9/10 thì tiếp tục sửa. Chỉ khi work đúng và điểm >9/10 mới commit + push code; sau push cập nhật `## Quyết định`, tick acceptance criteria, chuyển task sang `doc/task/done/`, commit + push lần hai.

