# I11 — Haptic feedback theo cỡ nhóm nổ

**Epic:** Cảm giác/A-V · **SP:** 2 · **Pri:** P1 · **Deps:** none

## Mục tiêu
Rung nhẹ/vừa/mạnh khi pop nhóm gem tuỳ theo số ô trong nhóm, tăng phản hồi xúc giác cho hit lớn.

## Vì sao
`HapticFeedback` (stdlib `package:flutter/services.dart`) đã dùng ở `level_select_screen.dart` cho unlock reveal — có sẵn, không cần thêm dependency. Game hiện chỉ phản hồi bằng particle + âm thanh, thiếu lớp xúc giác vốn rẻ và tăng "cảm giác đã tay" rõ rệt cho match-tap game.

## Acceptance criteria
- [ ] Pop nhóm `<4` ô: `HapticFeedback.lightImpact()`
- [ ] Pop nhóm `4..7` ô: `HapticFeedback.mediumImpact()`
- [ ] Pop nhóm `>=8` ô: `HapticFeedback.heavyImpact()`
- [ ] Bomb booster (3x3 trigger) rung `heavyImpact()` không phụ thuộc số ô ăn được
- [ ] Không rung khi tap trượt (không có nhóm hợp lệ, `group.length < 2`)
- [ ] `flutter analyze` 0 lỗi

## Subtasks (gợi ý file)
- `lib/game/pop_star_game.dart` — gọi `HapticFeedback.*` ngay tại nơi tính `group.length` trong `_tryPop` (sau khi xác nhận pop hợp lệ, trước/song song `_clearAndCollapse`); thêm nhánh tương tự trong `triggerBomb`.

## Ghi chú kỹ thuật
Không cần state/field mới — gọi trực tiếp theo `group.length` tại điểm pop, side-effect thuần, không ảnh hưởng test hiện có (haptic no-op trong test environment).

DoD chung: ../README.md.
