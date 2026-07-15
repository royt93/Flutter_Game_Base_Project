# F11 — Boss level mỗi world

**Epic:** Features · **SP:** 8 · **Pri:** Should · **Deps:** F4 (path map đã có), F6 (objective)

## Mục tiêu
Level cuối mỗi world (20, 40, 60...) là "boss level" — objective khó hơn hẳn
(kết hợp 2 objective, hoặc target cao hơn ramp thường theo công thức rõ ràng) +
icon/banner riêng trên path map.

## Vì sao
World hiện chỉ đổi tông màu, không có cột mốc cảm giác "ải khó" — boss level
tạo nhịp căng-chùng tự nhiên, tái dùng toàn bộ engine sẵn có.

## Acceptance criteria
- [x] Path map (F4) hiện icon boss riêng cho node cuối mỗi world.
- [x] Boss level: target/objective khó hơn ramp thường theo công thức xác định
      (không random tay, ví dụ hệ số nhân cố định lên `targetScore` ramp).
- [x] Thắng boss → hiệu ứng ăn mừng khác biệt (tái dùng `_WinChoreography` A5 +
      thêm nhãn "Boss cleared").
- [x] Test: đúng level nào là boss (`id % 20 == 0`), target boss cao hơn level
      thường liền trước.

## Subtasks (gợi ý file)
1. `lib/data/levels.dart`: đánh dấu `isBoss` + công thức target/objective riêng.
2. `lib/presentation/screens/level_select_screen.dart`: icon boss cho node.
3. `lib/presentation/screens/game_screen.dart`: banner thắng boss (mở rộng `_WinChoreography`).

## Ghi chú kỹ thuật
KHÔNG tạo cơ chế "trận đấu" mới — boss chỉ là level thường với threshold/objective
cao hơn + skin khác, tái dùng toàn bộ engine hiện có.

DoD chung: `../README.md`.

## Rà soát checkbox (2026-07-13)
Grep xác nhận: `lib/data/levels.dart` (`isBoss = id % 20 == 0`, `bossTargetMultiplier = 1.5`),
`level_select_screen.dart` (`_LevelTile` icon boss + viền gold), `game_screen.dart`
(`_WinChoreography` title "Boss Cleared!" khi `isBoss`), test `test/data/levels_test.dart`
(isBoss đúng level, target boss > level thường liền trước).
