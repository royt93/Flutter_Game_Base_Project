---
id: w11-conveyor
title: Băng chuyền (Conveyor belt)
wave: 11
status: done
owner: claude
---

# Băng chuyền — dịch gem mỗi lượt

Cơ chế CCS kinh điển còn thiếu. Hàng băng chuyền dịch toàn bộ gem 1 cột/lượt
(cyclic, wrap mép), sau dịch re-check match → cascade. Thêm chiều puzzle không gian.

## Việc
- `kConveyorLevels` (set chỉ số màn score) + cờ/ô băng chuyền theo HÀNG.
- Engine: sau `_finishMove` (mỗi lượt hợp lệ) → dịch hàng băng chuyền 1 cột, settle.
- Logic dịch thuần (test được) tách khỏi Flame.
- HUD badge "BĂNG CHUYỀN" + mũi tên hướng. Render dải băng chuyền.
- i18n en+vi. Guide.

## Test
- dịch cyclic đúng; wrap mép; nhiều hàng; tạo match sau dịch.

## Trạng thái — 🟡 in-progress
 → ✅ DONE
- `kConveyorSpec` {25,61} (hàng + hướng). Logic thuần `conveyorNewCol` (cyclic, test).
- Engine `_advanceConveyor()` sau settle mỗi lượt (hoán vị bijective + animate trượt/wrap), `ConveyorLayer` mũi tên chạy. HUD badge. i18n en+vi. +5 lượt.
- Test: pure (cyclic/wrap/bijection) + level spec.
