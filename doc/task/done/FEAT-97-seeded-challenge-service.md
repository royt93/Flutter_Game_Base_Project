---
id: FEAT-97
title: "Seeded challenge service offline deterministic"
type: feature
priority: P1
effort: M
source: "differentiator độc quyền"
---

## Vị trí

Mới, dùng `lib/core/utils/seeded_random.dart`, `lib/core/replay_recorder.dart:160`, `lib/core/reproduction_capsule.dart:30-44`, `lib/core/local_scoreboard_service.dart:29-44`, `lib/core/season_event_service.dart:34-46`.

## Hiện trạng

Kit đã có RNG snapshot/resume, replay + reproduction capsule, local scoreboard, season window riêng lẻ; chưa có service kết hợp chúng thành daily/weekly challenge seed cố định, replayable hoàn toàn offline.

## Vì sao cần / Hậu quả

Consumer phải tự nối nhiều primitive dễ lệch seed/clock/replay; mất differentiator "same challenge, reproducible run" không cần backend.

## Đề xuất

`SeededChallengeService`: derive seed từ `periodKey + challengeId`, cấp RNG stream/snapshot, attach replay capsule, submit local score. Dùng clamped/trusted clock để clock rewind không mở lại period cũ. Cookbook tile minh họa end-to-end. Ceiling: không network/global competition.

## Acceptance criteria

- [x] Cùng period + challengeId → seed/stream ổn định across restart.
- [x] Snapshot/resume RNG tạo chuỗi tiếp theo giống nhau.
- [x] Replay cùng seed/input → score deterministic; divergence được báo.
- [x] Leaderboard chỉ local, không gọi network.
- [x] Clock rewind không mở period cũ; fake clock test.
- [x] Cookbook tile demo flow, không vendor/backend.

## Quyết định

- **Implementation**: `SeededChallengeService` derive FNV-1a seed từ `periodKey:challengeId`, daily/weekly period qua clamped epoch day, tạo `SeededRandomService`, start/end replay capsule + divergence verification, và local scoreboard scoped theo challenge/period. Không network/vendor SDK. Export public API và Cookbook end-to-end demo.
- **TDD/verification**: 11 unit tests determinism/snapshot/replay/divergence/scoreboard/clock-rewind; Cookbook widget test pass; device persistent scoreboard test trên TECNO BG6 pass.
- **Gates**: root 2571/2571, example 202/202; API snapshot unchanged after regeneration; quality gates pass.
- **Audit**: independent fork 9.5/10.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify primitives tồn tại: `ReplayRecorder`, `ReproductionCapsule` kết hợp replay/RNG/trusted-clock, `LocalScoreboardService` local-only, `SeasonEventService` clamped-clock repeating window. Grep không thấy seeded challenge service hiện có.
