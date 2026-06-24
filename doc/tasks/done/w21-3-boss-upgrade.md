---
id: w21-3-boss-upgrade
title: Boss Mode — Phase HP + 3 attack pattern đa dạng
wave: 21
phase: 3
status: done
owner: claude
---

✅ **DONE 2026-06-23** — Phase HP system + cường độ retaliation theo phase.
`bossPhase` getter (0/1/2) dựa trên HP ratio. Interval [4,3,2] lượt, damage [1,2,3] moves.
HP bar màu cyan→yellow→red trong HUD. `bossAttackSignal` Rx trigger HUD flash.
Bỏ Meteor/Shuffle (cần engine callback, đặt cho wave sau).
**667 test pass** · 0 analyzer.

# Phase 3 — Boss Mode Upgrade

## Vấn đề hiện tại

Boss hiện tại (Wave 8): 1 cơ chế attack duy nhất (block gem ngẫu nhiên), HP giảm đều
khi combo. Người chơi quen sau 2-3 ván → mất thử thách.

## Thiết kế mới — Phase HP + 3 attack pattern

### Phase HP (3 giai đoạn)
- **Phase 1** (100-66% HP): "Tấn công nhẹ" — block 1 gem ngẫu nhiên/lượt (như hiện tại).
- **Phase 2** (65-33% HP): "Điên cuồng" — block 2-3 gem + đổi màu 1 gem ngẫu nhiên.
- **Phase 3** (32-0% HP): "Tuyệt vọng" — attack mỗi 2 lượt thay vì 3; thêm pattern Meteor.

Khi chuyển phase: flash màn hình màu boss + text "PHASE 2!" (dùng `NeonFlash` pattern).

### 3 Attack Pattern (xoay vòng ngẫu nhiên theo phase)

1. **Block** (hiện tại): đóng băng 1-3 gem (tùy phase), không match được 1 lượt.
2. **Meteor**: ném "asteroid" vào bàn — gem đích bị biến thành Stone obstacle (clear 2 lần).
   Số asteroid: 1 (P1), 2 (P2), 3 (P3). Dùng `ObstacleType.stone` đã có.
3. **Shuffle**: xáo toàn bộ bàn (không đảm bảo không-match → người chơi có thể hưởng lợi
   nếu nhanh). Chỉ xuất hiện ở P2+P3.

Xoay pattern: `List<BossPattern>` ngẫu nhiên (seed = boss round) → không repetitive.

### Data

```dart
// Trong levels.dart hoặc boss constants:
const kBossPhase2Threshold = 0.65;
const kBossPhase3Threshold = 0.32;
const kBossAttackInterval = [3, 3, 2]; // lượt/attack theo phase
```

## Triển khai

- `game_controller_modes.dart`: `_bossPhase` (0/1/2) computed từ `bossHp`/`bossMaxHp`.
- `game_controller_scoring.dart` `_doBossAttack()`: rẽ theo `_bossPhase` + `_bossPattern`.
- `neon_jewel_game.dart`: `applyMeteor(positions)` — set obstacle stone tại các ô.
- `effects.dart`: `BossAttackLayer` hiện overlay khi attack (icon theo pattern).
- HUD: thanh HP boss đổi màu theo phase (xanh → vàng → đỏ).

## Test
- Mỗi phase đúng attack interval.
- Meteor đặt stone đúng ô, không đặt trên wall/noDrop.
- Phase transition flash (widget test mock NeonFlash).
- Isolation: boss attack KHÔNG leak sang campaign.

## Lưu ý
- Pattern Shuffle tái dùng `_doShuffle` đã có (không viết lại).
- Stone obstacle đã có engine support → tái dùng `ObstacleType.stone`.
- Liên quan: [[side-mode-isolation]], [[w15-layout-architecture]].
