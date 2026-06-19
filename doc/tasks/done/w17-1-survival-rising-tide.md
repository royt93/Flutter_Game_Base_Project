---
id: w17-1-survival-rising-tide
title: Sinh tồn → Triều dâng (rising tide)
wave: 17
phase: 1
status: done
owner: claude
---

# Phase 1 — Sinh tồn: cơ chế "Triều dâng" (hết reskin TimeAttack)

> ✅ **DONE 2026-06-19** — engine ĐỌC `isSurvival` thật (update + resolveAll). Mực nước
> `_floodTop` dâng theo `tideRiseRate(elapsed)` (tăng tốc); clear gem dưới nước đẩy lùi
> (`kTidePushback`); chạm đỉnh → `tideOverflow` → checkEnd 'lose'. `TideLayer` (effects.dart)
> nước lam→đỏ. HUD ô-3 hiện "TRIỀU %". objective đổi `score` (bỏ timeAttack). i18n
> `hud_tide` + `survival_over`="NGẬP RỒI!/FLOODED!". **406 test pass · 0 analyzer**.
> CHƯA verify máy thật (chờ cáp USB — wireless yếu).

## Vấn đề hiện tại (audit)
Sinh tồn = TimeAttack đổi tên: `objective=timeAttack`, target=`1<<28` (vô cực), kết thúc
khi hết giờ. **Không một dòng engine nào đọc `isSurvival`** → 0 khác biệt gameplay so
với Time Attack. (Tham khảo `buildSurvivalLevel` trong `lib/data/levels.dart`.)

## Thiết kế mới — Triều dâng
Áp lực KHÔNG-GIAN thay vì chỉ áp lực thời gian:
- **Hàng gem rác dâng từ ĐÁY**: cứ mỗi `kTideInterval` giây (vd 12s, giảm dần theo
  thời gian sống), engine chèn 1 HÀNG gem mới ở đáy → đẩy toàn bộ bàn LÊN 1 ô.
- **Thua khi gem chạm ĐỈNH** (hàng 0 đầy & không còn nước đi an toàn) — KHÔNG phải hết giờ.
- **Đẩy lùi triều**: clear gem ở `kTideDangerRows` hàng sát đáy → trì hoãn lần dâng kế
  (hoặc hạ mực 1 hàng). Thưởng combo lớn = đẩy lùi nhiều.
- **Điểm = sống sót lâu + clear** → `survivalHigh` đổi sang "thời gian sống / số hàng đẩy lùi".

## Triển khai
- Engine `neon_jewel_game.dart`: thêm nhánh ĐỌC `controller.isSurvival` thật:
  - `_tideTimer` trong `update()` (tái dùng pattern `tickRhythm`/gravity flip).
  - `_raiseTide()`: dịch toàn bộ `grid` lên 1 hàng (giống `_applyJunk` của Versus —
    tái dùng logic đẩy bàn), spawn hàng đáy mới (tránh tạo match sẵn).
  - điều kiện thua: hàng 0 có gem sau khi dâng → `onGameEnd('lose')`.
- `game_controller_modes.dart` `startSurvival`: set cờ + cfg (bỏ target vô cực, dùng
  `objective` riêng hoặc giữ timeAttack nhưng KHÔNG dùng timeLeft làm điều kiện thua).
- `game_controller_scoring.dart`: nhánh `isSurvival` mới (thắng = N/A, kết toán theo
  hàng đẩy lùi / thời gian).
- Const tune: `kTideInterval`, `kTideAccel`, `kTideDangerRows`, `kTidePushback`.

## Test (unit + widget)
- `_raiseTide` dịch bàn đúng, không mất gem ngoài đáy, không tạo match sẵn.
- Thua khi đỉnh đầy; đẩy lùi khi clear sát đáy.
- ISOLATION: không đụng mạng/win-streak/level-unlock.
- Engine-mount widget test: mount Survival, tick tide vài lần → bàn dâng + vẫn `hasPossibleMove`.

## Lưu ý
- Tái dùng tối đa logic đẩy-bàn của Versus (`_applyJunk`) để khỏi viết lại.
- Cẩn thận winnability: hàng spawn phải luôn có nước đi (gọi `_ensurePlayable` sau dâng).
- Liên quan: [[side-mode-isolation]], [[w15-layout-architecture]].
