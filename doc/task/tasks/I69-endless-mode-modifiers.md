# I69 — Endless Mode Modifiers

**Epic:** Gameplay depth · **SP:** 5 · **Pri:** Should · **Deps:** tái dùng
`GauntletModifier`/`kGauntletModifiers`/`modifierForDay` (I33)

## Mục tiêu

Endless Mode có thêm 1 modifier luật chơi mỗi ngày — tái dùng đúng
`GauntletModifier` đã có ở I33, chọn theo epoch-day hiện tại (mọi người
chơi Endless cùng ngày gặp cùng 1 modifier). Modifier cố định suốt 1 run
(không đổi giữa các bàn trong cùng run). Không đổi công thức ramp độ khó
hiện có (`endlessLevelForIndex`), chỉ áp override có điều kiện lên trên.

## Vì sao

Endless hiện chỉ có 1 biến số (độ khó tăng dần theo `boardIndex`), không
có yếu tố luật-đổi bất ngờ như Gauntlet (I33) hay Treasure Map (I60). Tái
dùng thẳng `GauntletModifier` thay vì tạo class mới — đúng tinh thần class
đó vốn thiết kế để dùng chung nhiều mode (đã dùng cho cả Gauntlet lẫn
Treasure Map).

## Acceptance criteria

- [ ] `lib/data/levels.dart`: sửa `endlessLevelForIndex` thêm tham số tuỳ
  chọn:
  ```dart
  PopLevel endlessLevelForIndex(int boardIndex, {GauntletModifier? modifier})
  ```
  rows/cols giữ nguyên công thức ramp cũ; `colorCount` =
  `modifier?.colorCountOverride ?? (ramp cũ)`; thêm
  `gravityDirection: modifier?.gravityOverride ?? GravityDirection.down`
  (theo đúng mẫu hàm build `PopLevel` từ modifier đã dùng cho Gauntlet ở
  dòng ~280 cùng file).
- [ ] `GameController` thêm field `GauntletModifier? activeEndlessModifier`.
  Trong `startEndless()` (dòng ~1401) gán
  `activeEndlessModifier = modifierForDay(_todayEpochDay())` (tái dùng
  `kGauntletModifiers`, KHÔNG tạo `kEndlessModifiers` mới) và giữ nguyên
  suốt run — `advanceEndlessBoard()` (dòng ~1690) KHÔNG chọn lại modifier
  giữa các bàn, chỉ truyền `modifier: activeEndlessModifier` vào
  `endlessLevelForIndex`.
- [ ] Sửa `activeGameplayModifier` getter (dòng ~198) thêm nhánh
  `GameMode.endless => activeEndlessModifier`.
- [ ] Generalize 2 điểm hiện đang hardcode riêng cho Gauntlet để Endless
  cũng được áp dụng qua cùng field `activeGameplayModifier` (không viết
  logic riêng cho Endless):
  - Đổi `gauntletComboWindowOverride` (dòng ~194, hiện chỉ đọc khi
    `mode.value == GameMode.gauntlet`) thành getter chung
    `activeComboWindowOverride` đọc `activeGameplayModifier?.comboWindowOverride`
    bất kể mode — cập nhật 2 nơi gọi trong `pop_star_game.dart`
    (dòng ~738, ~924).
  - Đổi điều kiện chặn undo (dòng ~1993, hiện đọc thẳng
    `activeGauntletModifier?.disableUndo`) sang đọc
    `activeGameplayModifier?.disableUndo`.
  - `activeMoveLimit`/`activeMinGroupSize` đã đọc qua
    `activeGameplayModifier` sẵn — không cần sửa, tự động áp dụng cho
    Endless.
- [ ] UI: màn Endless hiển thị badge/icon modifier hôm nay — tái dùng
  đúng widget đã hiển thị modifier cho Gauntlet nếu đủ generic, không tạo
  widget mới nếu widget hiện có tái dùng được.
- [ ] Unit test: mở rộng `test/data/levels_test.dart` (hoặc file tương
  đương test `endlessLevelForIndex`) — truyền `modifier` có
  `colorCountOverride`/`gravityOverride` → kết quả `PopLevel` đúng
  override; không truyền `modifier` (mặc định `null`) → hành vi y hệt
  trước khi có I69 (regression test bảo vệ mọi test Endless cũ).
- [ ] Chạy lại `test/data/gauntlet_modifiers_test.dart` xác nhận Gauntlet
  không regress sau khi generalize `activeGameplayModifier`.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- KHÔNG sửa công thức `rows`/`cols`/`colorCount` ramp gốc trong
  `endlessLevelForIndex` — chỉ thêm override CÓ ĐIỀU KIỆN
  (`modifier?.xxx ?? rampCũ`), giữ đúng invariant "Endless ramp thuần theo
  boardIndex" cho mọi code gọi cũ không truyền `modifier` (mặc định
  `null` → hành vi y hệt trước đây, không phá test cũ).
- Modifier chọn 1 lần khi `startEndless()`, KHÔNG chọn lại mỗi bàn trong
  `advanceEndlessBoard()` — mọi bàn trong 1 run Endless nên cùng luật,
  đổi giữa chừng sẽ gây khó hiểu (khác Gauntlet vốn chỉ có 1 bàn/lượt chơi
  nên không gặp vấn đề này).
- Generalize `gauntletComboWindowOverride`/`disableUndo` có blast radius
  nhỏ (Gauntlet vẫn hoạt động y hệt vì `activeGameplayModifier` khi
  `mode.value == gauntlet` trả về đúng `activeGauntletModifier` như cũ) —
  vẫn phải chạy lại toàn bộ test Gauntlet hiện có để xác nhận không
  regress.

DoD chung: `../README.md`.
