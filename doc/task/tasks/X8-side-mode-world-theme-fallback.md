# X8 — Side-mode (Zen/TimeAttack/Endless/Daily) ăn nhầm theme world cuối

**Epic:** Bugfix · **SP:** 1 · **Pri:** Should · **Deps:** —

## Mục tiêu
`worldForLevel(id)` (`lib/data/worlds.dart:98`) fallback
`orElse: () => kWorlds.last` khi không world nào `contains(id)`. Side-mode
dùng id âm (`kTimeAttackLevel.id = -1`, `kZenLevel.id = -2`,
`kEndlessBoard...id = -3`, `kDailyChallengeLevel.id = -4`) — không world nào
chứa id âm nên luôn rơi vào `kWorlds.last`.

`lib/presentation/screens/game_screen.dart:43,45` dùng kết quả này để set
`accent`/`aurora` của nền — nghĩa là Zen/TimeAttack/Endless/Daily Challenge
đang hiện màu + hiệu ứng aurora (I16, vốn chỉ dành world 10 khó nhất) thay vì
theme trung tính.

## Vì sao
I16 aurora chỉ nên là phần thưởng thị giác cho world khó nhất (181-200), lộ
ra ở mọi side-mode làm mất ý nghĩa "world cuối" và không nhất quán (4 mode
khác nhau nhưng luôn cùng 1 theme world 10).

## Acceptance criteria
- [x] Side-mode (id ≤ 0) không dùng `worldForLevel` fallback về `kWorlds.last`
      — dùng theme trung tính/mặc định riêng (hoặc world đầu tiên) cho
      `accent`/`aurora` khi `currentLevel.id <= 0`.
- [x] Campaign level (id 1..200) hành vi giữ nguyên y hệt hiện tại.
- [x] Manual test: mở Zen/TimeAttack/Endless/Daily Challenge — không còn dải
      aurora phủ nền. (đã chạy tay trên emulator Android 2026-07-14, cả 4
      mode đều nền trung tính, không leak world 10)
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh.

## Subtasks
1. `lib/presentation/screens/game_screen.dart:43,45` — guard id ≤ 0 trước khi
   gọi `worldForLevel`, dùng giá trị mặc định (vd `kWorlds.first` hoặc màu
   trung tính cố định) cho side-mode.

## Ghi chú kỹ thuật
Không đổi `worldForLevel` chính nó (`orElse: kWorlds.last` vẫn hợp lý cho
input ngoài phạm vi bất ngờ) — chỉ tránh gọi nó với id âm ở call site.

## Đã code (2026-07-13)
`accent`/`aurora` chỉ tính `worldForLevel` khi `currentLevel.id > 0`; side-mode
(id âm) nhận `accent: null` (đã verify `NeonBg.accent` nullable + null-safe
toàn bộ widget), `aurora: false`. Campaign (id 1..200) không đổi hành vi.
`flutter analyze` 0 issues, `flutter test --exclude-tags slow` xanh.

DoD chung: `../README.md`.
