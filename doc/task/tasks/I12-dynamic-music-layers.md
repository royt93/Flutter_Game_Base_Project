# I12 — Dynamic music layers (nhạc thêm lớp theo combo)

**Epic:** Cảm giác/A-V · **SP:** 2 · **Pri:** P2 · **Deps:** none

## Mục tiêu
Nhạc nền "dày" thêm khi combo leo cao, tạo cảm giác căng/hype tăng dần thay vì
1 track phẳng suốt màn.

## Vì sao
`AudioManager` đã có 3 track nền (`bkg.ogg`/`bkg1.ogg`/`bkg2.ogg`) và cơ chế
đổi track qua `startBgm({int track})` (vốn chỉ dùng lúc khởi động), nhưng
combo hiện tại (`GameController.comboCount`) không tác động gì đến nhạc nền —
đây là hạ tầng có sẵn chưa được tận dụng cho mục đích "layering".

## Đề xuất
Không có audio stem/layer riêng trong asset (chỉ 3 track nhạc trọn vẹn) →
mô phỏng "thêm lớp" bằng cách **đổi track theo bậc combo** thay vì chồng lớp
âm thanh thật: combo thấp → track nền; combo vừa/cao → track cường độ hơn.
`startBgm` đã tự no-op nếu track hiện tại trùng track yêu cầu, nên gọi liên tục
mỗi lần combo đổi không tốn overhead.

## Acceptance criteria
- [x] Hàm thuần `AudioManager.bgmTierFor(comboCount)`: <3 → 0, 3..5 → 1, ≥6 → 2.
- [x] `AudioManager.applyComboLayer(comboCount)` gọi `startBgm(track:
      bgmTierFor(comboCount))`.
- [x] `GameController.registerPop` gọi `AudioManager.maybe?.applyComboLayer(
      comboCount.value)` sau khi combo cập nhật.
- [x] `GameController.resetCombo` gọi `AudioManager.maybe?.applyComboLayer(0)`
      để trả nhạc về track nền khi combo rớt.
- [x] Test thuần cho `bgmTierFor` (không cần widget harness):
      `test/core/audio_manager_test.dart`.
- [x] `flutter analyze` 0 lỗi; `flutter test --exclude-tags slow` xanh toàn bộ.

## Ghi chú kỹ thuật
Không thêm audio asset mới hay hệ thống mix nhiều track chồng lớp thật —
dùng lại nguyên cơ chế 3-track switching đã có (Ponytail rung 2: "đã có trong
codebase"). Nếu sau này có asset stem riêng, có thể nâng cấp
`applyComboLayer` sang chồng volume nhiều track cùng lúc mà không đổi API gọi
từ `GameController`.

DoD chung: ../README.md.

## Rà soát (2026-07-15)
`bgmTierFor`/`applyComboLayer` (`lib/core/audio_manager.dart`), wire vào
`registerPop`/`resetCombo` (`lib/presentation/controllers/game_controller.dart`).
Test `test/core/audio_manager_test.dart` pass; toàn bộ
`flutter test --exclude-tags slow` (231 test) pass sau khi thêm.
