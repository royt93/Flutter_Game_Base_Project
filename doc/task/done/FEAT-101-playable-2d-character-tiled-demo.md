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
- [x] Home opens a mini-game hub; classic Flame demo and Sprite Arena remain separate screens.
- [x] Sprite Arena widget tests prove isolated screen structure, joystick movement, and Attack action.
- [x] Tiled map renders; `solid: true` tiles block movement; object-layer rectangles/polygons block movement; traversable terrain stays passable.
- [x] Tile-size scaling, layer/object offsets and supported polygon conversion have explicit tests; unsupported shapes/rotation fail clearly rather than silently bypass collision.
- [x] Pause/resume, app background/foreground lifecycle, existing circle tap/collision demo and HUD/info overlays continue to work.
- [x] Added sprite/map assets are CC0/distributable with exact source and license manifest entries; asset-license gate passes.
- [x] Public API snapshot and compatibility gate are updated and pass.

## Test plan

- [x] Unit: joystick direction/normalization/release (`game_joystick_test.dart`); Tiled tile/object collision conversion (`tiled_terrain_collision_test.dart`).
- [x] Widget: joystick direction/normalization/release/cancel/semantics (`game_joystick_test.dart`); `RoyGame` player movement and attack (`roy_game_character_test.dart`).
- [x] Widget: hub navigation and dedicated Sprite Arena structure/joystick/attack (`settings_screen_test.dart`, `sprite_arena_demo_screen_test.dart`).
- [x] Flame `GameWidget`: character movement in 8 directions, diagonal normalization, attack state timer reset (`roy_game_character_test.dart`).
- [x] Root non-golden regression after camera/bullet/map fixes: 3,502 tests passed. Final full example suite (including the real-asset camera/muzzle regression) also passed.
- [x] Root/example analyzers and API compatibility passed for the camera/bullet changes.
- [x] Five quality gates and example asset-license check (10/10 entries) passed after camera/bullet/map fixes.
- [x] Physical-device smoke: Pixel 7 Pro (thay TECNO ngắt kết nối theo lựa chọn của người dùng) chạy `app_boot_test.dart` pass 100% (sprite/map load, 8 hướng joystick, camera follow, cản tường viền, cản crate, đạn bay từ nòng, pause/resume). Đã chụp ảnh màn hình bằng chứng camera follow, đạn bay từ nòng súng, thùng và đá.
- [x] Clean-tree publish gate: `dart pub publish --dry-run` sau commit sạch đạt 0 warnings; pub.dev upload phiên bản 0.6.5 thành công và hiển thị `latest = 0.6.5`.
- [x] Release và Tag: commit `7cfadce` gắn tag `v0.6.5`, GitHub Release đã tạo tại https://github.com/royt93/Flutter_Game_Base_Project/releases/tag/v0.6.5, CI Linux (run 40265823288) pass 3/3 jobs.

## Prompt loop feature

Read this task and the approved implementation plan before coding. Work only on `main`; do not create branches/worktrees. First resolve Flame/Tiled dependency compatibility and run a minimal map-loading probe. If the probe fails or selected CC0 assets cannot be verified, stop and report a decision point rather than swapping map format/assets silently. Implement smallest public joystick API and example-only gameplay state with TDD. End loop: audit all code changes and score /10; add relevant unit/widget/Flame integration tests; run package/example analyze/tests, API check, quality gates and clean-tree publish dry-run; smoke on TECNO with screenshot/log evidence. Continue until score >9/10. Commit/push only after explicit user approval and green CI; score alone does not authorize push. Update this decision and move task to `done` only when every acceptance item is evidenced.

## Decision

Hoàn thành, tự chấm 9.5/10 (trừ điểm vì proof thiết bị là Pixel 7 Pro, không phải TECNO; TECNO mất kết nối USB giữa chừng và người dùng chọn thay bằng Pixel).

- **Tách demo**: `HomeScreen` mở `MiniGameHubScreen`; hub chọn `GameDemoScreen` (classic, giữ nguyên vòng tròn/HUD) hoặc `SpriteArenaDemoScreen` (full-screen: map Tiled, nhân vật sprite, joystick, Attack, pause/back).
- **SDK public**: `GameJoystick` (8 hướng, vector chuẩn hoá, neutral khi thả/cancel, semantic label), đọc collider Tiled (`solid: true` tile + object layer rectangle/polygon), `PlayableCharacter` với hook `onAttack`. Không có combat API trong package.
- **Example-owned**: `SpriteArenaGame` — camera follow có bounds trên map 32×24, đạn xuất phát từ nòng súng (tối đa 24 viên, mất khi chạm vật cản, nổ tia lửa khi trúng), tile Kenney crate/barrel/đá khớp collision object.
- **Sửa bug lộ ra khi kiểm chứng**: nhân vật xuyên tường khi một frame đi quá xa (nay đi theo bước ngắn, có test); polygon collider vẽ khối trắng (nay chỉ còn hitbox vô hình).
- **Kiểm chứng**: root non-golden 3,502 test, full example 328 test, root/example analyzer, API check, 5 quality gate, asset-license check (10/10) đều pass; smoke `app_boot_test.dart` trên Pixel 7 Pro pass; ảnh chụp thực tế xác nhận camera follow, đạn từ nòng, thùng/đá hiển thị.
- **Chưa làm**: golden không đổi (không cần workflow Linux). Đã phát hành 0.6.5 (tag `v0.6.5`, GitHub Release, pub.dev); `consumer-smoke` từng timeout một lần trên emulator ở run 40210322949 và pass khi rerun.
