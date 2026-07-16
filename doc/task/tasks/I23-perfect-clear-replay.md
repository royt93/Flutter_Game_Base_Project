# I23 — Perfect Clear replay mode (thử thách vượt best score)

**Epic:** Meta/retention · **SP:** 2 · **Pri:** Should · **Deps:** —

## Mục tiêu
Cho phép chơi lại 1 level campaign đã qua (≥1 sao) với mục tiêu vượt best
score hiện tại của chính level đó. Thắng thử thách → thưởng thêm coin bonus
1 lần. Không thêm `GameMode` mới, không thêm StorageKey mới — tái dùng toàn
bộ luồng campaign hiện có. Spec đầy đủ tại
`docs/superpowers/specs/2026-07-16-perfect-clear-design.md`.

## Vì sao
User đang chơi tuyến tính 200 level, hết level mới hoặc đang chờ mở khoá thì
không còn động lực quay lại level cũ. Thử thách "đánh bại chính mình" (best
score cũ) tạo thêm 1 lớp động lực chơi lại mà không cần thêm nội dung level.

## Acceptance criteria
- [x] `GameController` — `perfectClearTarget` (`Rxn<int>`),
      `perfectClearSuccess` (`RxBool`), `perfectClearBonusCoins` (const 50).
      `startLevel()` reset cả 2 field về mặc định. `startPerfectClear(id)`
      chụp `StorageKeys.highScore(id)` làm target **trước** khi gọi
      `startLevel()` (tránh bị `_saveBestScore()` ghi đè ngay trong lượt
      đang xét).
- [x] `checkEnd()` — sau khi tính `starsEarned`/`ended`, nếu
      `perfectClearTarget != null && score > perfectClearTarget` → set
      `perfectClearSuccess = true`, cộng `perfectClearBonusCoins *
      weekendCoinMultiplier` vào coins, persist ngay. Không đụng nhánh
      star/highscore/unlock hiện có.
- [x] `LevelSelectScreen` — long-press trên tile đã unlock **và** đã có
      ≥1 sao mở dialog xác nhận (`NeonDialog.show`, 2 action cancel/start).
      Tap ngắn giữ nguyên hành vi chơi bình thường.
- [x] `game_screen.dart` win dialog — badge 🏆 hiện khi
      `perfectClearSuccess == true`, dùng chung choreography opacity với
      score.
- [x] i18n đủ 22 locale (`perfect_clear_title`, `perfect_clear_msg`,
      `perfect_clear_start`, `perfect_clear_success_label` — English +
      Vietnamese trong `_extraEn`/`_extraVi`, 20 ngôn ngữ còn lại trong wave
      map `_w36ByLang`).
- [x] Test: `test/presentation/game_controller_test.dart` group "Task #5 —
      Perfect Clear replay" (chụp target đúng, vượt target → thưởng đúng,
      không vượt → không thưởng, `startLevel` thường reset target/success).
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú
- Không dùng tiêu chí "ít nước đi hơn lần trước" (cần persist `movesUsed`
  tốt nhất theo level — thêm StorageKey mới) — chọn "vượt best score" vì tái
  dùng thẳng `StorageKeys.highScore(id)` đã có sẵn, diện thay đổi nhỏ hơn.
- Perfect Clear dùng nguyên `GameMode.campaign`, không phải mode riêng —
  tránh nhân bản nhánh campaign-vs-side-mode đã có trong `checkEnd`.

DoD chung: `../README.md`.
