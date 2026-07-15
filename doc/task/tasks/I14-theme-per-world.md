# I14 — Theme per world

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** F4

## Mục tiêu
Mỗi world (`worlds.dart`) có palette nền riêng — nền game (`NeonBg`) đổi theo
world của level đang chơi thay vì cố định 1 tông.

## Vì sao
Path map (F4) đã chia world theo màu banner, nhưng board trong lúc chơi vẫn 1
tông — theme trôi vào cả màn chơi tăng cảm giác "world khác nhau" rõ hơn.

## Acceptance criteria
- [x] `World` model (`worlds.dart`) thêm field màu/gradient palette.
- [x] `NeonBg` (hoặc `game_screen` background) nhận palette theo world của level
      đang chơi.
- [ ] Không phá contrast/đọc-được của gem màu ở bất kỳ world nào (kiểm bằng mắt) (chưa chạy tay kiểm bằng mắt trên device/simulator, chỉ verify code + test tự động)
- [x] Widget test: `NeonBg` nhận đúng palette theo `worldForLevel(id)`.

## Rà soát checkbox (2026-07-13)
- `lib/data/worlds.dart`: `GameWorld.color` field đã có sẵn (dùng làm palette).
- `lib/presentation/widgets/neon_bg.dart`: tham số `accent` (màu chủ đạo theo
  world, null = mặc định); `lib/presentation/screens/game_screen.dart` dòng
  ~47 truyền `worldForLevel(gameCtrl.currentLevel.id).color` vào `NeonBg`.
- `test/widget/game_screen_smoke_test.dart` có test "I14: NeonBg nhận đúng
  accent theo world của level đang chơi" assert `bg.accent == worldForLevel(25).color`.

## Subtasks (gợi ý file)
1. `lib/data/worlds.dart`: field palette mỗi world.
2. `lib/presentation/widgets/neon_bg.dart`: tham số palette.
3. `lib/presentation/screens/game_screen.dart`: truyền world hiện tại vào `NeonBg`.

## Ghi chú kỹ thuật
Tái dùng `NeonBg` sẵn có, chỉ tham số hoá màu — không viết background mới.

DoD chung: `../README.md`.
