---
id: w4-mode-drop-down
title: Mode — Drop Down
wave: 4
status: done
owner: claude
---

# Game Mode 4 — Drop Down (đưa item xuống đáy)

## Mục tiêu
Đưa đủ N "ingredient" (item đặc biệt) rơi xuống hàng đáy bàn.

## Thiết kế
- `ObjectiveType.dropDown` + `LevelConfig.dropTarget` (số item cần đưa xuống).
- **GemComponent**: thêm cờ `bool isIngredient` + render riêng (biểu tượng "◆ rơi" / mũi tên xuống phát sáng).
- **Logic**:
  - Ingredient KHÔNG tham gia match → loại khỏi `_colorGrid()` (trả null tại ô đó).
  - Rơi theo trọng lực như gem thường (vẫn nằm trong grid).
  - Sau mỗi `_applyGravityAndRefill`: quét hàng đáy; ô nào là ingredient → thu (animate biến mất), `controller.registerDrop()`, rồi gravity lại tới khi đáy hết ingredient.
  - Spawn: lúc bắt đầu màn, biến `dropTarget` gem ở hàng trên cùng thành ingredient (không refill thêm ingredient).
- **GameController**: `RxInt dropped`, `registerDrop()`, hasWon = dropped ≥ dropTarget, progress, stars (theo lượt còn).
- **HUD**: GOAL hiện icon item + `dropped/dropTarget`.

## Acceptance
- [x] registerDrop tăng đúng, hasWon khi đủ
- [x] ingredient không bị match, rơi đúng, thu ở đáy
- [x] không refill ingredient mới
- [x] unit test logic dropDown (controller)
- [x] analyze 0 issue · test pass · verify gameplay

## ✅ Kết quả
Hoàn thành Wave 4 — analyze 0 issue · 89 test pass · build APK debug OK.
