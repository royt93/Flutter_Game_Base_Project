---
id: ENH-82
title: "GameSessionController không đồng bộ với RoyLifecycleCoordinator/Flame pauseWhenBackgrounded — 2 cơ chế pause độc lập"
type: enhancement
priority: P1
effort: M
source: "claude + agy (độc lập xác nhận cùng vấn đề, 2 góc nhìn khác nhau cùng root cause)"
---

## Vị trí
`example/lib/screens/game_demo_screen.dart` (`_session = GameSessionController()..markReady()..start();`), `lib/core/game_session_controller.dart`, `lib/core/lifecycle_coordinator.dart`, Flame `FlameGame.pauseWhenBackgrounded`.

## Hiện trạng
`GameSessionController` không truyền/liên kết với `RoyLifecycleCoordinator` (đã đăng ký qua `RoyCasualKitModule.lifecycle` ở `main.dart`). Khi app bị background trong lúc chơi, Flame tự pause `FlameGame` (`pauseWhenBackgrounded` mặc định), nhưng `GameSessionController.snapshot` vẫn báo phase `playing` — 2 cơ chế pause độc lập, không đồng bộ.

## Vì sao cần / Hậu quả
Bất kỳ code nào rẽ nhánh theo `GameSessionPhase` (ví dụ để show `PauseOverlay`) sẽ sai trạng thái khi app resume từ background — game đã pause thật (Flame) nhưng UI/logic vẫn nghĩ đang `playing`. Đây là demo screen duy nhất cho Flame integration nên lỗi này dễ bị copy nguyên vào game thật của consumer.

## Đề xuất
Nối `GameSessionController` với `RoyLifecycleCoordinator`: đăng ký 1 lifecycle hook chuyển `GameSessionController` sang `paused` (với `GamePauseReason` phù hợp, ví dụ `backgrounded`) khi app vào background, và cân nhắc gọi `game.pauseEngine()`/`resumeEngine()` (Flame API) đồng bộ với đúng `GameSessionPhase` thay vì để Flame tự quyết định độc lập.

## Acceptance criteria
- [ ] App bị background trong lúc `GameSessionController.snapshot.value.phase == playing` — phase tự động chuyển `paused` (reason phù hợp) khi resume lifecycle event bắn ra.
- [ ] `PauseOverlay`/UI dựa vào `GameSessionPhase` phản ánh đúng trạng thái pause thật của Flame engine.
- [ ] `GameDemoScreen` minh hoạ đúng flow: background → resume → hiện đúng overlay pause nếu cần.
- [ ] Test widget/integration verify đồng bộ giữa lifecycle event và `GameSessionController` phase.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-82-game-session-lifecycle-flame-pause-not-synced.md` này trước khi làm. Đọc toàn bộ `lib/core/game_session_controller.dart`, `lib/core/lifecycle_coordinator.dart`, `example/lib/screens/game_demo_screen.dart`, và tài liệu Flame về `pauseWhenBackgrounded`/`pauseEngine`/`resumeEngine` trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test (`GameSessionController`+`RoyLifecycleCoordinator`) + widget test (`GameDemoScreen`) cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật (home button để background app trong lúc chơi demo, resume lại, verify state pause đúng) — bắt buộc vì đây là bug lifecycle chỉ tái hiện đầy đủ trên device thật (background/resume thật).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn độc lập (claude, agy) xác nhận cùng root cause qua 2 góc nhìn khác nhau (claude: thiếu liên kết `RoyLifecycleCoordinator`; agy: `PauseOverlay` demo không gọi Flame `pauseEngine()`) — cùng chỉ ra 1 khoảng trống thật: pause-state không đồng bộ giữa `GameSessionController`/lifecycle/Flame engine. Không trùng task nào trong `doc/task/done/`.
