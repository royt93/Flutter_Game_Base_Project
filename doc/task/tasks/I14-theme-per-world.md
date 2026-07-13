# I14 — Theme per world

**Epic:** Neon/Glow · **SP:** 5 · **Pri:** Could · **Deps:** F4

## Mục tiêu
Mỗi world (`worlds.dart`) có palette nền riêng — nền game (`NeonBg`) đổi theo
world của level đang chơi thay vì cố định 1 tông.

## Vì sao
Path map (F4) đã chia world theo màu banner, nhưng board trong lúc chơi vẫn 1
tông — theme trôi vào cả màn chơi tăng cảm giác "world khác nhau" rõ hơn.

## Acceptance criteria
- [ ] `World` model (`worlds.dart`) thêm field màu/gradient palette.
- [ ] `NeonBg` (hoặc `game_screen` background) nhận palette theo world của level
      đang chơi.
- [ ] Không phá contrast/đọc-được của gem màu ở bất kỳ world nào (kiểm bằng mắt).
- [ ] Widget test: `NeonBg` nhận đúng palette theo `worldForLevel(id)`.

## Subtasks (gợi ý file)
1. `lib/data/worlds.dart`: field palette mỗi world.
2. `lib/presentation/widgets/neon_bg.dart`: tham số palette.
3. `lib/presentation/screens/game_screen.dart`: truyền world hiện tại vào `NeonBg`.

## Ghi chú kỹ thuật
Tái dùng `NeonBg` sẵn có, chỉ tham số hoá màu — không viết background mới.

DoD chung: `../README.md`.
