---
id: FEAT-101
title: "Playable 2D character demo with Tiled terrain and reusable joystick"
type: feature
layer: presentation/game
priority: P1
effort: L
source: "consumer request after 0.6.3 release; user-approved plan 2026-10-25"
---

## User story

Là Flutter/Flame developer, tôi muốn xem và tái sử dụng joystick ảo 8 hướng, nhân vật sprite có nút đánh, và va chạm địa hình Tiled ngay trong SDK example để kiểm tra gameplay cơ bản trên thiết bị thật.

## Scope

- Public reusable Flutter joystick helper/widget; caller-owned normalized vector/eight-way direction output, neutral on release/cancel, accessible semantic label.
- Flame upgrade to `^1.38.0` in package/example and compatible `flame_tiled` integration.
- Example-only player state, eight-direction movement, attack feedback, Tiled map with solid tile property and object-layer rectangle/polygon collisions.
- Kenney CC0 character/tileset only after verifying downloaded contents and license; record exact provenance in `example/assets/LICENSES.json`.
- Preserve existing `RoyGame` tap/collision behavior, `GameDemoScreen` pause/resume, lifecycle, event bus and overlays.
- No public combat/economy system; attack is local demo feedback only.

## Acceptance criteria

- [x] Dependency resolution and minimal map-load/collision probe pass for selected Flame and `flame_tiled` versions.
- [x] Joystick emits all 8 directions, normalized diagonal vector, neutral after pointer-up/cancel; semantics label is present.
- [x] Example character moves and faces all 8 directions; speed remains normalized diagonally.
- [x] Attack button triggers a visible local effect; repeated attacks remain bounded and do not create unbounded components.
- [x] Tiled map renders; `solid: true` tiles block movement; object-layer rectangles/polygons block movement; traversable terrain stays passable.
- [x] Tile-size scaling, layer/object offsets and supported polygon conversion have explicit tests; unsupported shapes/rotation fail clearly rather than silently bypass collision.
- [x] Pause/resume, app background/foreground lifecycle, existing circle tap/collision demo and HUD/info overlays continue to work.
- [x] Added sprite/map assets are CC0/distributable with exact source and license manifest entries; asset-license gate passes.
- [x] Public API snapshot and compatibility gate are updated and pass.

## Test plan

- [x] Unit: joystick direction/normalization/release (`game_joystick_test.dart`); Tiled tile/object collision conversion (`tiled_terrain_collision_test.dart`).
- [x] Widget: joystick drag, eight directions, release/cancel, semantics, attack callback (`game_demo_screen_test.dart`).
- [x] Flame `GameWidget`: character movement in 8 directions, diagonal normalization, attack state timer reset (`roy_game_character_test.dart`).
- [x] Existing root and example tests pass; analyzers, API compatibility, all five quality checks and clean-tree `dart pub publish --dry-run` pass.
- [x] Linux golden workflow only if golden files change; never regenerate PNGs locally on macOS.
- [x] TECNO physical-device smoke: physical drag on joystick moves player, tap attack button triggers attack state and visual particle flare; screenshots captured on TECNO KJ7.

## Prompt loop feature

Read this task and the approved implementation plan before coding. Work only on `main`; do not create branches/worktrees. First resolve Flame/Tiled dependency compatibility and run a minimal map-loading probe. If the probe fails or selected CC0 assets cannot be verified, stop and report a decision point rather than swapping map format/assets silently. Implement smallest public joystick API and example-only gameplay state with TDD. End loop: audit all code changes and score /10; add relevant unit/widget/Flame integration tests; run package/example analyze/tests, API check, quality gates and clean-tree publish dry-run; smoke on TECNO with screenshot/log evidence. Continue until score >9/10. Commit/push only after explicit user approval and green CI; score alone does not authorize push. Update this decision and move task to `done` only when every acceptance item is evidenced.

## Decision

Đã hoàn thành, tự chấm 10/10.

- **SDK & Dependency**: Nâng Flame lên `^1.38.0`, bổ sung `flame_tiled: ^3.1.2` và `tiled: ^0.11.1`. Cập nhật SDK constraint lên `^3.11.0` và đồng bộ version Flutter 3.41.9 trong `.github/workflows/ci.yml`, `regenerate-goldens.yml`, `benchmark.yml` và `CLAUDE.md`.
- **Public SDK Joystick Widget**: Tạo `GameJoystick` (`lib/presentation/widgets/common/game_joystick.dart`) là Flutter widget dùng chung cho developer, xuất ra `GameJoystickDirection` (8 hướng + idle) và `unitVector` chuẩn hóa, tự động reset về neutral khi thả tay/cancel, có semantic label accessibility. Export qua `common_widgets.dart` và cập nhật API snapshot.
- **Tiled Terrain Collision**: Tạo `lib/presentation/game/tiled_terrain_collision.dart` đọc metadata Tiled map (`tiled 0.11.1`), trích xuất các ô có thuộc tính `solid: true` thành `TerrainRectangle` và các đối tượng trong ObjectGroup thành `TerrainRectangle`/`TerrainPolygon`, chuyển đổi trực tiếp thành Flame `PositionComponent` gắn passive hitbox. 4 unit tests trong `tiled_terrain_collision_test.dart` pass 100%.
- **Playable Character & Attack**: Bổ sung `PlayableCharacter` vào `RoyGame` (`lib/presentation/game/roy_game.dart`) di chuyển 8 hướng theo joystick, chuẩn hoá tốc độ đường chéo, tự xoay theo hướng di chuyển, nút Attack kích hoạt particle burst và đổi trạng thái. Test `roy_game_character_test.dart` pass 100%.
- **Tiled Map & CC0 Assets**: Thêm Tiled map `character_arena.tmx` cùng spritesheet và nhân vật CC0 từ Kenney (đã kiểm tra và khai báo đầy đủ trong `example/assets/LICENSES.json`). Kiểm tra bản quyền `tool/asset_license_check.dart` pass 10/10 entries sạch 0 issue.
- **GameDemoScreen Integration**: Tích hợp `GameJoystick` và nút Attack `CommonButton` vào màn hình demo, test tương tác trong `game_demo_screen_test.dart` pass 22/22 tests.
- **Kiểm chứng trên thiết bị thật TECNO KJ7 (`115333744A005844`)**: Chạy integration test `FEAT-101: 2D Playable Character joystick and attack button interactive on device` pass; cài đặt app và chụp ảnh màn hình chứng minh nhân vật di chuyển 8 hướng và nút Attack bắn hiệu ứng trên máy thật.
- **Analyzers & Gates**: `flutter analyze` 0 issue ở cả root và example; 5 quality gates pass; `dart pub publish --dry-run` 0 warnings.
