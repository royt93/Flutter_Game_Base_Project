---
id: BUG-35
title: "AchievementService chấp nhận threshold/progress sai và crash khi save bị corrupt"
type: bug
priority: P1
effort: S
source: Codex audit 2026-09-12
depends_on: []
---

## User story
Là game developer, tôi cần achievement progress luôn giữ invariant để dữ liệu import/corrupt hoặc call sai không tự unlock badge hay làm app crash.

## Hiện trạng và bằng chứng
`register()` ghi threshold bất kỳ và `incrementProgress()` cộng amount bất kỳ tại `lib/core/achievement_service.dart:95-107`. Threshold `<= 0` làm achievement hoàn thành ngay; amount âm làm progress lùi. `fromJson` force-cast mọi value sang `int` tại dòng 46 nên blob hợp lệ về envelope nhưng field sai kiểu vẫn throw khi service hydrate.

## Scope
- Định nghĩa invariant cho id rỗng, threshold, increment và overflow.
- Domain service phải xử lý save corrupt theo policy rõ ràng, không làm hỏng toàn bộ boot/session.
- Không mở rộng sang achievement catalog/server sync.

## Acceptance criteria
- [x] Public methods reject id rỗng, threshold không dương và amount không dương bằng lỗi rõ ràng trước mutation/write.
- [x] Corrupt progress entry không crash; policy bỏ entry hay reset blob được document và test.
- [x] Progress hợp lệ vẫn persist/reload, rapid increments không regression race đã fix ở BUG-17.
- [x] Unit, widget, integration và device smoke test bao phủ happy/edge/error/corrupt case.

## Implementation evidence

- `register()` validates non-empty IDs and positive thresholds before touching the registry.
- `incrementProgress()` validates IDs/amounts, rejects integer overflow and only then mutates or queues a save.
- Progress deserialization now keeps only non-empty IDs with non-negative integer values; corrupt entries are dropped and a defensive catch keeps hydration from breaking boot.
- Tests cover invalid input, corrupt JSON/domain values, overflow, widget rendering after recovery, persistence and the existing BUG-17 save race.
- Integration smoke `BUG-35` passed on Samsung SM S928B (`R5CX613VZBR`, Android 16/API 36) with `--dart-define=E2E_TEST=true`.
- Root and `example/` passed `flutter analyze` and `flutter test --exclude-tags slow`.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng TDD. Kết thúc mỗi vòng phải: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy `flutter analyze` và `flutter test --exclude-tags slow` ở root lẫn `example/`; smoke test trên Android device thật và ghi screenshot/log làm bằng chứng. Nếu chưa đạt >9/10 thì tiếp tục sửa. Chỉ khi work đúng và điểm >9/10 mới commit + push code; sau push cập nhật `## Quyết định`, tick acceptance criteria, chuyển task sang `doc/task/done/`, commit + push lần hai.
