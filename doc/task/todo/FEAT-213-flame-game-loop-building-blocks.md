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

- Audit / điểm:
- Tests/device smoke:
- Hiệu năng trước/sau:
- Commit/push:
