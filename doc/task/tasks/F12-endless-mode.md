# F12 — Endless mode

**Epic:** Features · **SP:** 8 · **Pri:** Should · **Deps:** F8 (tái dùng khung side-mode timeAttack/zen)

## Mục tiêu
Mode Endless: bàn tự sinh cấu hình khó dần (rows/cols/colors tăng theo số bàn
đã qua), chơi tới khi bàn kẹt hẳn (`hasAnyMovableGroup` false) — không target,
chỉ ghi high-score.

## Vì sao
Tái dùng toàn bộ engine pop/collapse hiện có, chỉ cần generator config mới —
rủi ro code thấp, đáp ứng nhu cầu "chơi không giới hạn".

## Acceptance criteria
- [x] `GameMode` thêm `endless`; config sinh động (không cố định trong `kLevels`)
      theo công thức ramp liên tục (không chia world).
- [x] Kết thúc khi `hasAnyMovableGroup(grid)` false — không có targetScore/thắng-thua,
      chỉ hiện điểm cuối + high-score.
- [x] High-score lưu riêng (`StorageKeys` mới, không đụng key level thường).
- [x] Unit test: generator sinh board hợp lệ tăng khó theo số bàn; kết thúc
      đúng khi kẹt.

## Subtasks (gợi ý file)
1. `lib/data/levels.dart` hoặc file mới `endless_config.dart`: hàm sinh
   `PopLevel` theo index.
2. `lib/presentation/controllers/game_controller.dart`: endless high-score key.
3. Entry point ở home/level_select (tái dùng pattern F8 timeAttack/zen).

## Ghi chú kỹ thuật
Tái dùng `_checkEnd`/`hasAnyMovableGroup` có sẵn, không viết vòng lặp kết thúc
riêng.

DoD chung: `../README.md`.

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `game_controller.dart` (`GameMode.endless`, `endlessBest`), `lib/data/levels.dart`
(`endlessLevelForIndex` — ramp liên tục, không chia world, targetScore=0),
`pop_star_game.dart` (`_checkEnd` sang bàn kế khi clear, kết thúc khi kẹt/`hasAnyMovableGroup`),
`storage_service.dart` (`endlessBest` key riêng), test `test/data/levels_test.dart` +
`test/widget/modes_test.dart`.
