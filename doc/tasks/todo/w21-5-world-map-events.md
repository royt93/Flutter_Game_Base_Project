---
id: w21-5-world-map-events
title: World Map — Event chest + mini-boss node + nhân vật đi bộ
wave: 21
phase: 5
status: partial
owner: claude
---

> 🟡 **Phần CHEST đã implement 2026-06-26** (W22 Phase 2):
> - Data: `chestLevelOf(w)` (trung điểm, xử lý TG không đều), `kChestLevels`,
>   `chestCoinReward(world)` (tất định, levels.dart).
> - Storage: `StorageKeys.chestClaimed(world)`; Economy: `isChestUnlocked` (≥80% màn TG),
>   `isChestClaimed`, `claimWorldChest` (guard-key TRƯỚC → idempotent chống farm).
> - UI: `_chestNodes`/`_chestNode` trong world_map (node rương lệch khỏi node màn; khoá/mở/đã nhận).
> - resetProgress xoá chest keys; 6 unit test; analyze 0; full suite 768 pass. Map render sạch (verify Samsung).
> **CÒN LẠI (defer):** mini-boss node (B) + avatar đi bộ (C) + reward overlay đẹp + chest reward
> ngẫu-nhiên-booster (hiện chỉ xu). Để wave sau.
---

# Phase 5 — World Map Events

## Vấn đề hiện tại

World Map (Wave 5.3/6): node màn uốn lượn, path neon, xung năng lượng, sao lấp lánh.
Nhưng map là **tĩnh** — không có gì khác nhau mỗi thế giới ngoài màu accent.

## Code grounding (đã verify 2026-06-25)

| Thành phần | File:line | Ghi chú |
|---|---|---|
| Screen + tap → game | `lib/presentation/screens/world_map_screen.dart:23` (`WorldMapScreen`), `:36` (`_play`) | `_play` check story + pregame rồi `ctrl.startLevel(index)` → `Get.to(GameScreen)` |
| Vị trí node X (zig-zag) | `world_map_screen.dart` `fx(i)= 0.5 + 0.27*sin(i*0.9)` | dùng cho avatar |
| Hằng layout | `_vGap=96`, `_topPad=92`, `_nodeSize=46` | Y của node `i` = `_topPad + (i-1)*_vGap` |
| Animation host | `_AnimatedMap`/`_AnimatedMapState:247` | `AnimationController` 6s repeat; build node bằng `Positioned` loop `:325-331` |
| Painter (path/sao/xung) | `_MapPainter:490`, `_segment():569` (quadraticBezier) | tái dùng để vẽ glow |
| World mapping | `lib/data/levels.dart:364-375` `kWorlds` (10 TG), `worldOfLevel(level):1142`, `kWorldSize=20` | **TG không đều**: TG8=141-150 (10 màn), TG10=171-200 (30 màn) |
| Boss entry | `game_controller_modes.dart:289` `startBoss(int stage)`; HP = `kBossBaseHp + (stage-1)*700` | **không có param maxHp** → xem mục B |
| Economy | `game_controller_economy.dart` `addCoins()` (ghi guard-key trước) | dùng cho chest |
| CustomPainter mẫu glow | `_MapPainter.paint()` blur + halo (xem agent report) | avatar ~30 dòng |

## Thiết kế (đã sửa theo code thật)

### A. Treasure Chest Node (Rương báu)

Mỗi thế giới có **1 rương báu tại màn TRUNG ĐIỂM** thế giới.
- ⚠️ **Sửa giả định cũ** (`{1:10,2:30...}` sai vì TG8/TG10 không đều): dùng
  `chestLevelOf(w) = (w.startLevel + w.endLevel) ~/ 2` → TG1=10, TG8=145, TG10=185.
- Data: `List<int> kChestLevels = kWorlds.map((w)=>(w.startLevel+w.endLevel)~/2).toList();`
- Node rương nhỏ màu vàng neon, **chèn cạnh** node màn trung điểm (offset X lệch ~30px để
  không đè node màn), KHÔNG phải node "màn chơi".
- Tap → `ChestRewardOverlay` (dùng `NeonDialog.overlay`): thưởng xu ngẫu nhiên (50-150)
  hoặc booster ×1. **Random tất định theo world** (seed=world) để không farm reload.
- Mở khoá khi đã hoàn thành ≥ `(size*0.8).ceil()` màn trong TG (size = endLevel-startLevel+1).
- Nhận **1 lần/thế giới** — persist key `StorageKeys.chestClaimed(world)` (thêm key mới).
- Badge "🎁" chưa nhận → "✓" sau nhận.

### B. Mini-Boss Node (Quái trùm nhỏ)

Mini-boss node đặt **giữa 2 thế giới** (sau node cuối TG chẵn: TG2,4,6,8,10), KHÔNG đè
màn campaign (vì `w.endLevel` đã là màn Super-Hard thật).
- Data: `kMiniBossWorlds = [2,4,6,8,10]`; node nằm ngay dưới node `w.endLevel` của các TG đó
  (chèn một slot Y phụ `_vGap` giữa world boundary).
- Icon đầu lâu neon nhấp nháy (tái dùng pulse của `_MapPainter`).
- Tap → vào **Boss Mode HP thấp**. ⚠️ `startBoss` không nhận maxHp → **2 lựa chọn**:
  - (ưu tiên) Thêm optional param: `startBoss(int stage, {double hpScale = 1.0})` →
    `bossMaxHp.value = (kBossBaseHp + (stage-1)*700) * hpScale ~/ 1;` gọi `startBoss(1, hpScale: .5)`.
  - (tối giản) Gọi `startBoss(1)` (stage 1 = HP thấp nhất sẵn có) — không cần sửa core.
- Thắng → `addCoins(3× thưởng boss thường)` + set `miniBossCleared(world)` (persist).
- Thua: thử lại ngay, **không trừ mạng** (đã có: boss `isSideMode` không đụng lives — xem
  `[[side-mode-isolation]]`).

### C. Nhân vật đi bộ dọc path (Cosmetic)

Avatar neon (viên kim cương glow) ở node hiện tại, "đi" mượt khi mở map.
- Vị trí: `x = fx(current)*width`, `y = _topPad + (current-1)*_vGap` (toạ độ node hiện tại).
- `AnimatedPositioned` (0.5s) từ node trước → node hiện tại khi `_AnimatedMapState` mount.
- Vẽ bằng `_GemAvatarPainter` (CustomPainter ~30 dòng, mirror blur+halo của `_MapPainter`).
- Chạy 1 lần khi map mở (không loop, tránh tốn battery).

## Thứ tự triển khai (đề xuất)

1. **Data** (`levels.dart`): thêm `kChestLevels`, `kMiniBossWorlds`, helper `chestLevelOf`.
2. **Storage** (`storage_service.dart`): thêm `chestClaimed(world)`, `miniBossCleared(world)`.
3. **Economy** (`game_controller_economy.dart`): `claimWorldChest(world)` (ghi guard-key
   TRƯỚC khi `addCoins`, idempotent), `isChestClaimed(world)`, `isMiniBossCleared(world)`.
4. **(nếu chọn B-ưu-tiên)** `startBoss` thêm optional `hpScale`.
5. **UI** (`world_map_screen.dart`): `_buildChestNode()`, `_buildMiniBossNode()`, chèn vào
   `Positioned` loop; `_GemAvatarPainter` + avatar `AnimatedPositioned`.
6. **Overlay**: `ChestRewardOverlay` widget (NeonDialog.overlay).
7. **i18n**: keys `chest_title/chest_reward/miniboss_title/...` vào `_extraEn`+`_extraVi`.
8. **Test** + `flutter analyze` (0 issue).

## Acceptance criteria

- [ ] `chestLevelOf` đúng cho cả TG đều và không đều (TG1→10, TG8→145, TG10→185).
- [ ] `claimWorldChest(w)` gọi 2 lần chỉ cộng xu **1 lần** (anti-exploit; guard-key trước await).
- [ ] Chest reward tất định theo world (cùng world → cùng phần thưởng, không farm reload).
- [ ] Chest khoá tới khi hoàn thành ≥80% màn TG.
- [ ] Mini-boss: thua KHÔNG trừ mạng; thắng set `miniBossCleared` (persist, restart không mất).
- [ ] Mini-boss HP < boss thường stage tương ứng.
- [ ] Avatar đứng đúng node `currentLevel`; mount không crash.
- [ ] `resetProgress()` xoá `chestClaimed_*` + `miniBossCleared_*` (chống re-claim — xem `[[reset-permanent-controllers]]`).
- [ ] Widget test: `WorldMapScreen` mount với chest + mini-boss node (skipOffstage:false).
- [ ] `flutter analyze` 0 issue.

## Lưu ý

- Mini-boss tái dùng boss engine sẵn — chỉ đổi HP. Reward dùng `addCoins` (guard-key trước).
- ⚠️ Phải thêm xoá key mới vào `resetProgress()` — nếu không sẽ re-claim sau reset.
- Liên quan: [[side-mode-isolation]], [[currency-persistence-convention]], [[reset-permanent-controllers]].
