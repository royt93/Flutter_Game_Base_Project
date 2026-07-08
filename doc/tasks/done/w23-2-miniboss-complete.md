---
id: w23-2-miniboss-complete
title: Mini-boss hoàn thiện — cleared persist + thưởng + attack pattern
wave: 23
phase: 2
status: done
owner: claude
---

> 🟡 **2A done 2026-06-26**: `isMiniBoss`/`miniBossWorld` (set ở `startBoss`, reset ở
> `_enterMode`); `StorageKeys.miniBossCleared(world)`; `grantMiniBossClear` (guard-key TRƯỚC,
> +120 xu 1 lần) gọi ở boss-win; node mini-boss đã-hạ → icon verified + dim (đánh lại không
> thưởng lại); thêm vào `resetProgress`. 6 unit test, analyze 0, full suite 783 pass.
> **2B (done 2026-06-27, trừ meteor)**: selector `bossAttackPatternFor(phase)` (PURE,
> `logic/boss_attack.dart`) + getter `GameController.bossAttackPattern` (phase 0-1=block, 2=shuffle)
> + 4 test. **Shuffle attack ĐÃ WIRE** trong `neon_jewel_game` (mẫu move-handler): capture
> `bossAttackSignal` trước `useMove`, nếu boss + signal tăng + pattern=shuffle → `await _doShuffle()`
> SAU cascade settle (chỉ chạy khi isBoss → non-boss không ảnh hưởng). analyze 0, suite 810.
> **Meteor (done 2026-07-08)**: `bossAttackPatternFor` trả `BossAttack.meteor` ở phase ≥2
> (<32% HP, ngưỡng `kBossPhase3Threshold`); wire trong `neon_jewel_game` cùng mẫu shuffle —
> telegraph 1 lượt (`_pendingMeteor`/`_showMeteorWarning`) rồi `_doMeteorAt` (clear-cell, tái
> dùng animation nổ có sẵn) + `_meteorSettleNoScore` (refill KHÔNG cộng điểm) ở lượt kế; vùng
> chọn qua `pickMeteorRegion` (pure, 3×3 quanh tâm ngẫu nhiên, chỉ ô play có gem — không đụng
> wall/noDrop). analyze 0, suite 963 pass.
> **Device-verify xong 2026-07-08** (Pixel 7 Pro `2B051FDH3006MU`): cày mini-boss Ải 1 xuống
> Giai Đoạn 2 → thấy shuffle nổ đúng lượt (mất 1+2=3 lượt khớp `kBossAttackDamage[1]`, bàn xáo
> lại full khớp `_doShuffle`); cày tiếp xuống Giai Đoạn 3 (<32% HP) → thấy icon telegraph
> meteor xuất hiện đúng ô (`_showMeteorWarning`), mất 1+3=4 lượt khớp `kBossAttackDamage[2]`;
> thắng boss ở combo lớn ngay sau đó (Chiến Thắng 3 sao, +120 xu — đúng thưởng mini-boss ×3).
> Logcat sạch suốt trận (không crash/ANR), không ad che UI. Đóng task.
---

# Phase 2 — Mini-boss hoàn thiện

## Hiện trạng (sau W22.5)
Mini-boss node đã có: `kMiniBossWorlds [2,4,6,8,10]`, vào Boss HP thấp qua
`startBoss(1, hpScale: 0.5)` + `Get.to(GameScreen)`. **Chưa** có: tracking "đã hạ", thưởng
riêng, và attack pattern (chỉ Block — Meteor/Shuffle defer từ w21-3).

## Việc

### 2A. Tracking + thưởng "đã hạ mini-boss"
- ⚠️ Cần biết ván boss hiện tại LÀ mini-boss (để set cleared + thưởng đúng). Thêm
  `RxBool isMiniBoss` (hoặc cờ nội bộ) set trong `startBoss` khi `hpScale < 1`.
- `StorageKeys.miniBossCleared(world)`; set khi THẮNG boss mà `isMiniBoss==true`
  (hook ở nhánh boss-win của `checkEnd`/scoring — xem `game_controller_scoring.dart`).
- Thưởng khi hạ lần đầu: `addCoins(3× thưởng boss thường)` hoặc 1 booster (guard-key TRƯỚC).
- Node mini-boss đã hạ → đổi visual (check/dim), vẫn cho đánh lại nhưng KHÔNG thưởng lại.
- Thêm `miniBossCleared(world)` vào `resetProgress` (loop kMiniBossWorlds) — chống re-claim.

### 2B. Attack pattern Meteor/Shuffle (defer từ w21-3)
- Hiện boss chỉ Block gem ngẫu nhiên. Thêm:
  - **Meteor**: phá 1 vùng nhỏ (cần callback engine xoá cell) — đồng bộ animation.
  - **Shuffle**: xáo lại bàn (đã có cơ chế auto-shuffle khi hết nước đi → tái dùng).
- Chọn pattern theo `bossPhase` (P1 block, P2 +meteor, P3 +shuffle) — leo thang độ khó.
- ⚠️ Cần hook engine (NeonJewelGame) → rủi ro cao hơn 2A; có thể tách lần sau.

## Acceptance
- [x] Thắng mini-boss lần đầu → `miniBossCleared(world)=1` + thưởng 1 lần; đánh lại không thưởng.
- [x] Thua mini-boss KHÔNG trừ mạng ([[side-mode-isolation]]).
- [x] `isMiniBoss` reset đúng khi vào mode khác (không "rò" sang boss thường).
- [x] `resetProgress` xoá `miniBossCleared_*`.
- [x] (2B nếu làm) attack pattern theo phase, không phá invariant thắng-được.
- [x] Unit test (cleared persist + thưởng 1 lần + reset) + widget (node cleared visual). analyze 0.

## Lưu ý
- 2A rủi ro thấp (logic + persist). 2B đụng engine Flame → cân nhắc tách phase riêng.
- Liên quan: [[side-mode-isolation]], [[currency-persistence-convention]], [[reset-permanent-controllers]].
