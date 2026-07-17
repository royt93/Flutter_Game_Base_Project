# I25 — Boss variant mới cho 11 world (task #15)

**Epic:** Content · **SP:** 2 · **Pri:** Should · **Deps:** F11 (boss target ×1.5), F9 (ObjectiveType hiện có), I24 (World 11)

## Mục tiêu
Đa dạng hoá trận boss (level cuối mỗi world) — thay vì mọi boss đều dùng
objective `score` mặc định, luân phiên 4 variant theo `world % 4`, tái dùng
nguyên `ObjectiveType` đã có sẵn cơ chế/test (`clearColor`,
`obstacleInMoves`, `openGift`, `score`), không thêm mechanic mới.

## Vì sao
11 boss level hiện tại (20, 40, ..., 220) đều giống nhau về mục tiêu (chỉ
khác kích thước bàn/target) — thiếu cảm giác "trận chốt" khác biệt giữa các
world. `clearColor`/`obstacleInMoves`/`openGift` đã có đầy đủ cơ chế trong
`pop_star_game.dart`/`game_controller.dart` (dispatch thuần theo
`ObjectiveType`, không phân biệt boss/thường) nên gán lại objective cho boss
là thay đổi cấu hình dữ liệu, không phải mechanic mới — rủi ro thấp nhất
theo nguyên tắc "tái dùng trước khi phát minh".

## Acceptance criteria
- [x] `lib/data/levels.dart`: boss level (`isBoss == true`) không còn theo
      chu kỳ 9-slot chung (`slot = i % 9`) — dùng `bossVariant = world % 4`
      để chọn objective riêng: `0`→`score`, `1`→`clearColor`,
      `2`→`obstacleInMoves`, `3`→`openGift`.
- [x] `targetScore`/`bossTargetMultiplier` của boss level giữ nguyên hoàn
      toàn — chỉ đổi `objective`, không đổi công thức target (invariant
      achievability không bị ảnh hưởng).
- [x] Màn thường (không boss) vẫn theo đúng chu kỳ 9-slot cũ, không đổi
      hành vi.
- [x] `test/data/levels_test.dart`: test cũ `'objective luân phiên đúng chu
      kỳ 9 màn'` đổi tên thêm `(màn thường)` + bỏ qua `isBoss`; thêm test mới
      `'boss variant luân phiên đúng theo world % 4'` xác nhận đúng
      `ObjectiveType` cho từng boss theo world.
- [x] Test target-achievability sẵn có (`'boss targetScore vẫn trong khoảng
      khả thi mở rộng'`, `'boss target = target thường × bossTargetMultiplier
      ...'`) vẫn pass không cần sửa — xác nhận đổi objective không đụng
      target.
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Rà soát checkbox (2026-07-17)
Grep xác nhận: `bossVariant = world % 4` (`levels.dart:140`), switch riêng
cho `isBoss` tách khỏi switch `slot` màn thường (`levels.dart:141-163`).
`test/data/levels_test.dart` có 2 test tách biệt: dòng ~106 (màn thường, có
`if (kLevels[i].isBoss) continue;`) và dòng ~128 (`'boss variant luân phiên
đúng theo world % 4'`). Không đụng `targetScore`/`bossTargetMultiplier`.
Smoke test: `flutter analyze` → 0 issues; `flutter test --exclude-tags
slow` → 246/246 pass (từ 245 trước khi thêm test boss variant).

## Subtasks (gợi ý file)
1. `lib/data/levels.dart` — tách switch objective cho boss theo
   `bossVariant`.
2. `test/data/levels_test.dart` — sửa test 9-slot bỏ qua boss, thêm test
   boss variant mới.

## Ghi chú kỹ thuật
Không cần đổi `lib/data/worlds.dart` hay UI (`level_select_screen.dart`,
`game_screen.dart`) — badge boss (viền vàng) hiện có đã đủ báo hiệu "đây là
trận chốt"; objective khác biệt được surface tự nhiên qua UI generic đã
tồn tại cho mọi level có objective non-score (icon/label mục tiêu trên
`game_screen.dart`). `objectiveMet` (game_controller.dart) kết thúc màn ngay
khi đạt objective bất kể `score` đã chạm `targetScore` hay chưa — hành vi
này đã đúng cho màn thường có objective khác score, nên boss variant thừa
hưởng y hệt, không phải rủi ro mới.

DoD chung: `../README.md`.
