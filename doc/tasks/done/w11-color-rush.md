---
id: w11-color-rush
title: Chế độ Truy Quét Màu (Color Rush)
wave: 11
status: done
owner: claude
---

# Color Rush — màu nóng đổi liên tục, đua điểm

Mode phụ (như Rhythm/Gravity): mỗi N lượt chọn ngẫu nhiên 1 màu "nóng"; clear màu
nóng → điểm BỘI (×2..3). Đạt điểm mục tiêu trong số lượt. KHÔNG đụng mạng/streak.

## Việc
- Cờ `isColorRush` + `buildColorRushLevel()` + `startColorRush()` (dùng isSideMode!).
- checkEnd nhánh riêng (thắng theo điểm, thưởng xu, side-mode isolation).
- Engine: registerClear màu nóng → bội điểm; đổi màu nóng mỗi N lượt.
- HUD: chip "MÀU NÓNG ●" + bội số. Nút Home + Guide. i18n en+vi.

## Test
- đổi màu nóng theo lượt; clear màu nóng bội điểm; side-mode không đụng tiến trình.

## Trạng thái — 🟡 in-progress
 → ✅ DONE
- Cờ `isColorRush` + `buildColorRushLevel` + `startColorRush` (vào `isSideMode`).
- `tickColorRush` đổi màu nóng mỗi 4 lượt (tất định cyclic); `colorRushBonus` +15đ/gem nóng.
- checkEnd nhánh riêng (side-mode isolation). Engine đếm gem màu nóng trong `_clearCells`.
- HUD chip MÀU NÓNG ●; nút Home full-width nổi bật; Guide; i18n en+vi.
- Test: start/tick/bonus/side-mode isolation (7).
