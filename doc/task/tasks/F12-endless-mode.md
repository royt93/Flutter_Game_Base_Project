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
- [ ] `GameMode` thêm `endless`; config sinh động (không cố định trong `kLevels`)
      theo công thức ramp liên tục (không chia world).
- [ ] Kết thúc khi `hasAnyMovableGroup(grid)` false — không có targetScore/thắng-thua,
      chỉ hiện điểm cuối + high-score.
- [ ] High-score lưu riêng (`StorageKeys` mới, không đụng key level thường).
- [ ] Unit test: generator sinh board hợp lệ tăng khó theo số bàn; kết thúc
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
