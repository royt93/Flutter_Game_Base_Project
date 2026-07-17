# I24 — Thêm World 11 (level 201-220)

**Epic:** Content · **SP:** 3 · **Pri:** Should · **Deps:** F4 (level path map), F11 (boss per world)

## Mục tiêu
Mở rộng campaign từ 200 lên 220 level bằng cách thêm World 11 (level
201-220), tái dùng đúng công thức ramp/clamp hiện có trong
`lib/data/levels.dart` — không thiết kế lại đường cong khó.

## Vì sao
Người chơi hoàn thành World 10 (level 200) cần thêm nội dung để tiếp tục
tiến trình campaign. Vì `rows`/`cols`/`colorBase` trong generator đều dùng
`.clamp` trên biểu thức theo `world`, chúng đã bão hoà ở trần từ World 10 —
World 11 tự động dùng đúng trần đó (rows 11, cols 12, colorBase 7) với `ramp`
nhích thêm, không cần đổi logic sinh level.

## Acceptance criteria
- [x] `kLevelCount` tăng từ 200 → 220 trong `lib/data/levels.dart`, doc
      comment cập nhật theo (không còn nói "200 màn").
- [x] `targetScore` của toàn bộ 20 level mới vẫn thoả invariant achievability
      (`perCell = targetScore / (rows*cols)` trong `[4, 9]`, hoặc
      `[4, 9*bossTargetMultiplier]` cho level boss) — test
      `test/data/levels_test.dart` xác nhận qua toàn bộ `kLevels`, không cần
      guard riêng cho World 11.
- [x] `kWorlds` (`lib/data/worlds.dart`) có thêm entry World 11: `startId:
      201`, `endId: 220`, màu `NeonTheme.lime` (chưa dùng cho world nào
      trước), icon `Icons.diamond_rounded` (không trùng icon 10 world
      trước), `nameKey: 'world_path_name_11'`.
- [x] i18n: key `world_path_name_11` thêm vào `_extraEn` ("Diamond Nebula")
      và `_extraVi` ("Tinh Vân Kim Cương") trong `app_translations.dart` —
      đúng theo pattern hiện tại của `world_path_name_1..10` (English làm
      fallback cho 20 ngôn ngữ chưa dịch riêng, `app_translations_test.dart`
      không yêu cầu bản dịch riêng cho mọi locale).
- [x] `test/data/levels_test.dart`: sửa loop cứng `world < 10` →
      `world < kLevelCount ~/ 20` để tự bao phủ World 11.
- [x] `test/data/worlds_test.dart`: thêm test riêng xác nhận World 11 tồn tại
      đúng range/nameKey và màu không trùng 10 world trước (test tổng quát
      sẵn có trong file đã tự bao phủ World 11 qua `kWorlds`/`kLevelCount`).
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ (245/245).

## Rà soát checkbox (2026-07-17)
Grep xác nhận: `kLevelCount = 220` (`levels.dart:99`); `kLevels` generator
dùng `world = i ~/ 20` (0..10) không đổi công thức; `kWorlds` có 11 entry,
entry cuối `startId: 201, endId: 220, color: NeonTheme.lime, icon:
Icons.diamond_rounded, nameKey: 'world_path_name_11'`
(`worlds.dart`); `world_path_name_11` có trong `_extraEn`/`_extraVi`
(`app_translations.dart:723,1393`). Test mới trong `worlds_test.dart` group
`'World 11'` (2 test) + loop bound sửa trong `levels_test.dart`. Smoke test:
`flutter analyze` → 0 issues; `flutter test --exclude-tags slow` → 245/245
pass (từ 243 trước khi thêm 2 test World 11).

## Subtasks (gợi ý file)
1. `lib/data/levels.dart` — bump `kLevelCount`.
2. `lib/data/worlds.dart` — thêm `GameWorld` entry World 11.
3. `lib/core/app_translations.dart` — thêm `world_path_name_11` vào
   `_extraEn`/`_extraVi`.
4. `test/data/levels_test.dart`, `test/data/worlds_test.dart` — cập nhật/
   thêm test.

## Ghi chú kỹ thuật
Không cần đổi bất kỳ logic ramp/clamp nào trong `kLevels` generator — đây là
điểm mấu chốt giúp World 11 "miễn phí" về mặt thiết kế khó: công thức đã là
hàm tổng quát theo `world = i ~/ 20` nên chỉ cần tăng hằng số. Nếu sau này
thêm World 12+, lặp lại đúng quy trình này (không thiết kế lại).

DoD chung: `../README.md`.
