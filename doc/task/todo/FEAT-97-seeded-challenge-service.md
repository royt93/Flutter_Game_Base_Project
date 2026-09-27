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

- [ ] Cùng period + challengeId → seed/stream ổn định across restart.
- [ ] Snapshot/resume RNG tạo chuỗi tiếp theo giống nhau.
- [ ] Replay cùng seed/input → score deterministic; divergence được báo.
- [ ] Leaderboard chỉ local, không gọi network.
- [ ] Clock rewind không mở period cũ; fake clock test.
- [ ] Cookbook tile demo flow, không vendor/backend.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

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
