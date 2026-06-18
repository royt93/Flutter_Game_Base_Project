---
id: w11-portal
title: Cổng dịch chuyển (Portal)
wave: 11
status: done
owner: claude
---

# Cổng dịch chuyển — định tuyến lại trọng lực

Cặp ô cổng exit→entrance: khi refill, cột có entrance ở đỉnh hút gem từ cột chứa
exit thay vì sinh mới → gem "chui" cổng. Tạo combo bất ngờ + puzzle định tuyến.

## Việc
- `kPortalLevels` + định nghĩa cặp cổng (exitCol→entranceCol) theo màn.
- Engine: hook vào `_applyGravityAndRefill` — cột entrance kéo từ exit.
- HUD badge "CỔNG". Render cặp cổng (vòng xoáy 2 màu khớp cặp).
- i18n en+vi. Guide.

## Test
- gem đi từ exit sang entrance; gravity định tuyến đúng; không mất/nhân gem.

## Trạng thái — 🟡 in-progress
 → ✅ DONE
- `kPortalSpec` {43,85} (cặp ô). Logic thuần `buildPortalLinks`+`expandPortals` (2 chiều, 1 hop).
- Engine: expand tập clear trong `_clearCells` → clear 1 đầu echo đầu kia. `PortalLayer` vòng xoáy cặp màu. HUD badge. i18n.
- Test: pure (link 2 chiều, expand 1 hop, no-loop).
- MVP: echo = clear trực tiếp (không kích special của đối tác).
