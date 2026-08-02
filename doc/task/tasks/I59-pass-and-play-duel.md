# I59 — Pass-and-Play Duel

**Epic:** Gameplay depth (social) · **SP:** 5 · **Pri:** Could
· **Deps:** không (tái dùng seed generator + puzzleLab pattern)

## Mục tiêu

2 người chơi luân phiên trên cùng 1 máy, mỗi người chơi 1 bàn cùng seed
(bàn giống hệt nhau nhưng độc lập, không chia đôi 1 bàn), so điểm cuối
cùng, hiện màn "ai thắng".

## Vì sao

Khác I37 (challenge code offline-async, chia sẻ code để chơi sau) — đây
là social đồng bộ tại chỗ (cùng ngồi 1 máy), tăng viral tại chỗ trong dịp
tụ tập gia đình/bạn bè, không cần chia sẻ code hay mạng.

## Acceptance criteria

- [ ] Thêm `GameMode.passAndPlay` vào enum
  (`lib/presentation/controllers/game_controller.dart` dòng 38-49).
- [ ] Hàm mới `startPassAndPlayDuel()` tái dùng chính xác pattern
  `startPuzzleLevel(grid)` (dòng 1175-1197) — sinh 1 seed ngẫu nhiên, tạo
  grid qua `generateDailyChallengeGrid(seed)`, deep-copy grid trước mỗi
  lượt để cả 2 người chơi cùng 1 bàn gốc giống hệt nhau.
- [ ] Controller nhỏ mới `PassAndPlayController` (GetX, cô lập theo đúng
  pattern `BossRushController` — không đụng `GameController` core) quản
  lý: `currentPlayer.obs` (1|2), `player1Score`, `player2Score`, chuyển
  lượt khi `GameController.ended` bắn true (nghe qua
  `ever(gameCtrl.ended, ...)` đúng convention "Reactive unlock / async
  end" trong CLAUDE.md).
- [ ] Màn hand-off giữa 2 lượt: dialog `NeonDialog.overlay` (không dùng
  `Get.dialog`/`showDialog` — theo "Dialog pattern" CLAUDE.md) hiện "Đưa
  máy cho Người chơi 2" trước khi bắt đầu lượt 2 với grid gốc y hệt
  (không phải state đã pop dở của người 1).
- [ ] Sau lượt 2: màn kết quả so điểm, hiện người thắng (điểm cao hơn)
  hoặc hoà.
- [ ] Không ghi `highScore(id)`/`star(id)` campaign, không cộng
  coin/booster — duel thuần vui chơi tại chỗ, tránh lạm dụng nhân đôi
  phần thưởng qua 2 lượt.
- [ ] Entry point từ `home_screen.dart` (thẻ mới trong
  `buildHomeCards`, theo pattern các mode khác).
- [ ] Unit test cho phần logic chuyển lượt/tính thắng-thua-hoà (tách pure
  logic ra khỏi GetX nếu có thể để test không cần bootstrap GetX đầy đủ).
- [ ] i18n toàn bộ text màn hand-off + kết quả, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- `generateDailyChallengeGrid(seed)` là pure/deterministic — gọi 2 lần
  cùng seed cho ra grid giống hệt, mỗi lượt cần deep-copy list trước khi
  đưa vào `PopStarGame` vì engine mutate `colorGrid` trực tiếp khi chơi.
- `PopStarGame` dùng cùng 1 engine instance cho mọi mode — giữa 2 lượt
  cần reset đúng qua flow start-level bình thường của
  `GameScreenController`, không giữ state cũ từ lượt 1 sang lượt 2.
- `GameController.ended` là tín hiệu kết-thúc-ván hiện có duy nhất —
  không có sẵn khái niệm "lượt" tách biệt "ván", `PassAndPlayController`
  là nơi thêm khái niệm lượt mới, không sửa `GameController` core.

DoD chung: `../README.md`.
