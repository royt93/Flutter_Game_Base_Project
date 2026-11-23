---
id: FEAT-213
title: "Khối dựng game loop Flame dùng lại: input, camera, spawn, pause"
type: feature
layer: lib/presentation/game + example
priority: P2
effort: L
source: "Owner chọn hướng game 2026-11-22; lib/presentation/game chỉ có roy_game.dart, pooled_component.dart, tiled_terrain_collision.dart, trong khi sprite_arena_game.dart (example) tự ghép joystick/camera/spawn/pause"
---

## Hiện trạng đã xác minh

- Package: `RoyGame` (shell tối thiểu), `PooledComponent`, `tiled_terrain_collision.dart`, widget `GameJoystick`, `PauseOverlay`, `FlameTrackedOverlay`, `GameSessionController`.
- `example/lib/game/sprite_arena_game.dart` + `arena_actors.dart` (monster, pickup, bullet) tự ghép các phần trên; chưa rõ phần nào đủ chung để trích ra.

## Việc cần làm trước khi thiết kế

- Đọc `sprite_arena_game.dart` và `game_demo_screen.dart`, liệt kê đúng những pattern lặp lại ở CẢ HAI game. Chỉ trích ra thứ có ít nhất hai nơi dùng, tránh thiết kế cho nhu cầu giả định.
- Đo baseline hiệu năng Sprite Arena trên Samsung S24U (đã có baseline boot) trước khi đổi để so sánh trước/sau.

## Phạm vi đề xuất (sau khi xác minh)

- Trích khối nhỏ, mỗi khối có test: nối `GameJoystick` -> vận tốc component, camera follow, spawner dùng `PooledComponent`, liên kết `GameSessionController` (pause/resume) với vòng lặp Flame.
- Đưa vào `lib/presentation/game/`, export + API snapshot + CHANGELOG. Sprite Arena chuyển sang dùng khối mới, không đổi hành vi.

## Acceptance criteria

- [ ] Danh sách pattern lặp lại có bằng chứng (đường dẫn/dòng) trước khi code.
- [ ] Mỗi khối có test không cần thiết bị (Flame `GameWidget` smoke, dùng `TickerMode`/bounded pump vì game loop là Ticker vĩnh viễn).
- [ ] Sprite Arena + Classic Flame test hiện có vẫn pass; không giảm FPS so baseline (đo trên thiết bị thật, ghi số liệu).
- [ ] API snapshot + CHANGELOG; audit >9/10; device smoke thiết bị thật, không simulator.

## Kết quả thực hiện

- **Phạm vi thực tế (owner chọn 2026-11-23): MỘT khối nhỏ, không phải bộ game loop đầy đủ.** Khảo sát cho thấy trong code hiện có chỉ một pattern lặp ở nhiều nơi: cầu nối `GameSessionController` -> pause/resume engine (`GameDemoScreen` dùng worker `ever()`, Match-3 tự đồng bộ session). Joystick, camera, spawn wave chỉ `SpriteArenaGame` dùng (và `SpriteArenaGame` có `ArenaPhase` riêng, không dùng session của kit), nên không đủ điều kiện "ít nhất 2 nơi dùng" của spec; để không thiết kế API cho nhu cầu giả định, không trích.
- Thay đổi: `GameSessionEngineBridge` (`lib/presentation/game/game_session_engine_bridge.dart`, export từ `roy_casual_kit.dart`): pause engine khi session `paused`, resume khi về `playing`, mọi nguồn pause (overlay, gọi tay, app xuống nền qua `RoyLifecycleCoordinator`) cùng đường; loading/ready/won/lost không đụng engine; đồng bộ trạng thái ngay lúc tạo; `dispose()` idempotent. `GameDemoScreen` bỏ worker tự viết, dùng bridge. Match-3 không có `FlameGame` nên không áp dụng.
- Tests: 7 test mới (pause đóng băng và resume chạy lại thật trên `RoyGame`, session đã paused từ trước, nhiều lý do pause chỉ resume khi hết cả hai, nền/tiền cảnh qua lifecycle, restart qua ready/start, phase loading/ready/terminal không đụng engine kể cả engine đang pause chủ ý, dispose dừng nghe và gọi lặp an toàn). Mutation check: không pause, không resume, bỏ đồng bộ ban đầu, resume cả phase khác, dispose không hiệu lực đều làm test đỏ; hai mutant dispose chỉ bị bắt khi gỡ cả hai lớp bảo vệ cùng lúc (cố ý hai lớp). `GameDemoScreen` 22 test cũ pass nguyên. Root 4104 pass, example 472 pass, analyze, API gate (chỉ thêm, Removed rỗng), accessibility, performance budget, deprecation sạch.
- Device: Pixel 7 Pro (không phải S24U), Android 17, debug `E2E_TEST=true`: test sẵn có `BUG-91/BUG-92: GameDemoScreen pause FAB dừng Flame engine thật` pass với bridge mới, log `doc/task/evidence/FEAT-213-pixel7pro-gamedemo-pause-bridge.log`.
- Hiệu năng: KHÔNG đo FPS và đây là chủ ý. Thay đổi không động vào vòng lặp update/render, chỉ thay một worker bằng class tương đương logic (bridge gọi đúng `pauseEngine`/`resumeEngine` như worker cũ), nên không có cơ sở để kỳ vọng thay đổi FPS; không tạo số liệu trước/sau giả. Nếu sau này trích khối joystick/camera/spawn thì phải đo Pixel 7 Pro (hoặc S24U) trước và sau.
- Không làm (cố ý): khối input/joystick, camera follow, spawner wave; mở lại khi có game Flame thứ hai thật sự dùng chung.
- Audit / điểm: ~9.0/10. Trừ điểm: nhỏ hơn nhiều so với spec ban đầu; `SpriteArenaGame` chưa dùng bridge (có `ArenaPhase` riêng); không đo FPS.
- Commit/push:
