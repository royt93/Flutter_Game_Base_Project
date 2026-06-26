---
id: w23-2-miniboss-complete
title: Mini-boss hoàn thiện — cleared persist + thưởng + attack pattern
wave: 23
phase: 2
status: todo
owner: claude
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
- [ ] Thắng mini-boss lần đầu → `miniBossCleared(world)=1` + thưởng 1 lần; đánh lại không thưởng.
- [ ] Thua mini-boss KHÔNG trừ mạng ([[side-mode-isolation]]).
- [ ] `isMiniBoss` reset đúng khi vào mode khác (không "rò" sang boss thường).
- [ ] `resetProgress` xoá `miniBossCleared_*`.
- [ ] (2B nếu làm) attack pattern theo phase, không phá invariant thắng-được.
- [ ] Unit test (cleared persist + thưởng 1 lần + reset) + widget (node cleared visual). analyze 0.

## Lưu ý
- 2A rủi ro thấp (logic + persist). 2B đụng engine Flame → cân nhắc tách phase riêng.
- Liên quan: [[side-mode-isolation]], [[currency-persistence-convention]], [[reset-permanent-controllers]].
