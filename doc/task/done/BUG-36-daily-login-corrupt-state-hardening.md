---
id: BUG-36
title: "DailyLoginService tin dữ liệu domain corrupt và có thể crash/sinh streak vô lý"
type: bug
priority: P1
effort: M
source: Codex audit 2026-09-12
depends_on: []
---

## User story
Là người chơi, tôi cần daily-login tự phục hồi an toàn khi backup/save cũ bị sai để app vẫn mở và không phát thưởng sai.

## Hiện trạng và bằng chứng
Deserializer tại `lib/core/daily_login_service.dart:77-83` force-cast list sang `int` và không validate `streakDay`, epoch day hoặc claimed set. `VersionedJsonStore` chỉ bảo vệ envelope; dữ liệu domain sai vẫn có thể throw hoặc đưa giá trị ngoài 1..7 vào logic modulo.

## Scope
- Parse defensive bằng safe-json/domain validator.
- Chọn policy recovery nguyên tử cho state không nhất quán: reset an toàn hoặc normalize khi có thể chứng minh không tăng quyền lợi.
- Giữ anti-clock-rewind và save serialization hiện tại.

## Acceptance criteria
- [x] Sai type, giá trị âm/quá cycle, list lẫn type và tổ hợp state mâu thuẫn không crash.
- [x] Recovery không cấp thêm reward và state sau recovery thỏa mọi invariant.
- [x] Save hợp lệ cũ tiếp tục round-trip; race coverage BUG-18 vẫn pass.
- [x] Unit, widget, integration và device smoke test bao phủ happy/edge/error/corrupt case.

## Implementation evidence

- Added a defensive domain parser that validates epoch day, streak range, claimed-day types/range and cross-field consistency.
- Any malformed or contradictory state resets atomically to the safe initial state (`streakDay: 0`, no claimed days), so recovery cannot grant an extra reward.
- Hydration catches unexpected store/domain errors while preserving valid legacy round-trips and BUG-18 save serialization.
- Tests cover wrong types, negative/out-of-cycle values, mixed lists, contradictory state, safe widget rendering, valid claims, persistence and rapid claim saves.
- Integration smoke `BUG-36` passed on Samsung SM S928B (`R5CX613VZBR`, Android 16/API 36) with `--dart-define=E2E_TEST=true`.
- Root and `example/` passed `flutter analyze` and `flutter test --exclude-tags slow`.

## Quyết định

Audit score: **9.5/10**. Work meets the task contract and is ready to commit/push.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan trước khi làm. Implement bằng TDD. Kết thúc mỗi vòng phải: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case; chạy `flutter analyze` và `flutter test --exclude-tags slow` ở root lẫn `example/`; smoke test trên Android device thật và ghi screenshot/log làm bằng chứng. Nếu chưa đạt >9/10 thì tiếp tục sửa. Chỉ khi work đúng và điểm >9/10 mới commit + push code; sau push cập nhật `## Quyết định`, tick acceptance criteria, chuyển task sang `doc/task/done/`, commit + push lần hai.
