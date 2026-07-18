# I27 — Prestige / New Game+

**Epic:** Meta/retention · **SP:** 5 · **Pri:** Should · **Deps:** không

## Mục tiêu
Khi người chơi đã unlock hết 220 level (11 world), cho phép "Prestige":
reset `unlockedLevel` về 1 và chơi lại **đúng 220 level hiện có** (không
sinh level mới) nhưng với 1 hệ số khó tăng dần theo mỗi tier prestige —
`targetScore` hiệu dụng nhân lên theo tier. Có badge tier hiển thị, coin
thưởng khi prestige để giữ động lực.

## Vì sao
Người chơi hoàn thành hết campaign muốn có lý do chơi lại. Vì project chủ
trương "không backend" nên không tạo nội dung mới liên tục được — tái dùng
chính 220 level đã cân bằng kỹ (xem `CLAUDE.md` mục Target achievability)
cộng thêm hệ số nhân là giải pháp rẻ nhất, đúng tiền lệ đã có
(`bossTargetMultiplier` nhân target theo điều kiện level).

## Acceptance criteria
- [ ] `GameController`: `RxInt prestigeTier` (0 = chưa prestige) +
      `StorageKeys.prestigeTier`. Getter `canPrestige` =
      `unlockedLevel.value > kLevelCount`. Method `prestige()`: tăng
      `prestigeTier`, reset `unlockedLevel = 1`, thưởng coin theo tier;
      **không** xoá high score/star cũ (không phạt lịch sử chơi).
- [ ] `lib/data/levels.dart`: hàm pure `prestigeTargetScore(PopLevel level,
      int tier)` — ví dụ `level.targetScore * (1 + tier * 0.25)` (làm tròn),
      tier 0 trả đúng `targetScore` gốc. Không đổi field gốc `targetScore`
      trên `PopLevel`.
- [ ] Luồng chấm điểm/`checkEnd` dùng `prestigeTargetScore(level,
      prestigeTier.value)` thay vì `level.targetScore` trực tiếp khi
      `prestigeTier > 0`.
- [ ] UI: dialog xác nhận trước khi prestige (hành động khó đảo ngược —
      không tự động, phải người chơi bấm xác nhận); badge tier (vd "P1",
      "P2"...) hiển thị cạnh level hiện tại ở `LevelSelectScreen` và
      `HomeScreen`. Entry point Prestige chỉ hiện khi `canPrestige == true`.
- [ ] `resetProgress()` xoá luôn `prestigeTier` về 0.
- [ ] i18n đủ 22 locale cho dialog xác nhận + badge label.
- [ ] Test pure: `prestigeTargetScore` (tier 0 = gốc, tier tăng đúng công
      thức, làm tròn hợp lý). Test `GameController.prestige()`: tăng tier,
      reset unlockedLevel, không đụng high score/star cũ.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- `kLevelCount = 220` (`lib/data/levels.dart`, world 11 đã thêm ở phiên
  trước — **không phải 200** như ghi trong `CLAUDE.md`, cần lưu ý khi
  implement để không giới hạn sai điều kiện `canPrestige`).
- `unlockedLevel` observable + `_unlockNext()` (kiểm tra `next <=
  kLevelCount`) nằm trong `lib/presentation/controllers/game_controller.dart`.
- Tiền lệ hệ số nhân target: `bossTargetMultiplier = 1.5`
  (`lib/data/levels.dart`).
- `worldForLevel(int id)` (`lib/data/worlds.dart`) không cần đổi — world
  vẫn map theo `id` gốc 1-220, tier chỉ đổi target, không đổi rows/cols/màu.

DoD chung: `../README.md`.
