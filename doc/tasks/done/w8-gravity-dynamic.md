---
id: w8-gravity-dynamic
title: Trọng lực động / Mê cung neon (signature)
wave: 8
status: done
owner: claude
---

# Chế độ Trọng lực động — gem rơi theo hướng thay đổi

> ĐỘC QUYỀN: hiếm game match-3 có. Tận dụng sẵn booster **Gravity Flip** đang có
> → nâng thành 1 cơ chế/mode hoàn chỉnh. Dễ tạo clip viral ("bàn cờ xoay").

## Cơ chế
- Lưới có **hướng trọng lực** thay đổi: xuống (mặc định) → trái → phải → lên.
- Đổi hướng theo: số lượt (mỗi N lượt), theo zone (vùng grid), hoặc do gem đặc biệt.
- Khi đổi hướng → gem "rơi" lại theo hướng mới (tái dùng logic gravity của
  `neon_jewel_game.dart`, tổng quát hoá `_applyGravity` theo `GravityDir`).
- **Mê cung**: thêm ô "tường" (không gem) định hình đường rơi → ghép có chủ đích.

## Việc cần làm
- Tổng quát hoá gravity hiện tại (đang hard-code rơi xuống) thành tham số hướng.
- `GravityDir { down, up, left, right }` + chuyển toạ độ khi cascade.
- Mode mới `ObjectiveType.gravityMaze` HOẶC modifier áp lên mode có sẵn.
- HUD: mũi tên chỉ hướng trọng lực hiện tại + animation xoay bàn khi đổi.

## Rủi ro / lưu ý
- Logic match detection KHÔNG đổi (match theo hàng/cột vẫn vậy) — chỉ gravity đổi.
- Phải đảm bảo "no dead board" sau khi đổi hướng (kiểm tra còn nước đi).
- Đây là phần KHÓ về engine — làm sau khi Wave 7 ổn định.

## Test
- gravity 4 hướng dồn đúng; cascade theo hướng; tường chặn rơi; board luôn có nước đi.

## Trạng thái — ✅ DONE (MVP: lật bàn định kỳ, tái dùng engine an toàn)
`ObjectiveType.score` + cờ `isGravity` + `buildGravityLevel()`; GameController `startGravity()`,
`consumeGravityFlip()` (lật mỗi `kGravityFlipEvery`=5 lượt, đổi `gravityDir`); engine refactor tách
`_doColumnFlip()` dùng chung booster + mode, gọi trong lượt khi gravity mode; HUD badge hướng ↓/↑,
nút GRAVITY Home, i18n en+vi. Lưu ý: bản đầu lật bàn (đảo cột) — trọng lực 4 hướng + tường là bước sâu
hơn (xem mô tả trên), để dành.
Kết quả: 0 analyzer · test `test/w8_gravity_test.dart` (5) pass.
