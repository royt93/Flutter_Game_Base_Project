---
id: w14-soda-mode
title: Chế độ Soda / Ngập nước
wave: 14
status: done
owner: claude
---

# Soda mode — mực nước dâng, đưa chai nổi lên đỉnh

Mode phụ (như Color Rush/Rhythm): clear gem → mực nước dâng → đẩy "chai nổi"
(floater) lên trên. Đưa đủ K chai chạm hàng đỉnh → thắng. KHÔNG đụng mạng/streak.

Thiết kế tránh đụng gravity/refill (phần dễ vỡ): floater là gem có cờ `isFloater`
(không match, swap-lock như ingredient). Mỗi lượt hợp lệ: waterLevel += gemClear;
khi vượt mốc → mỗi floater dịch LÊN 1 hàng (hoán đổi với gem phía trên). Floater
chạm hàng 0 → thu được (`sodaCollected++`). Hook an toàn sau `_settle()`.

## Việc
- Cờ `isSoda` + `buildSodaLevel()` + `startSoda()` (vào `isSideMode`).
- Engine: `isFloater` gem, `_buildSoda`, `_riseSoda` (sau settle), thu floater ở đỉnh.
- checkEnd nhánh riêng (thắng khi đủ chai, thưởng xu, side-mode isolation).
- HUD: chip "CHAI ●/K" + thanh mực nước. Nút Home + Guide. i18n en+vi.

## Test
- start/đủ chai → win; mực nước dâng đẩy floater; side-mode không đụng tiến trình.
