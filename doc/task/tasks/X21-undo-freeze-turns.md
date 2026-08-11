# X21 — Undo không khôi phục `freezeTurnsLeft` → mất 1 lượt Freeze đã hoàn tác

**Epic:** E6 Hardening · **SP:** 2 · **Pri:** Should · **Mức:** P2
**Deps:** — · **Cùng nhánh với:** [[X17]] [[X20]] · **Liên quan:** [[F10]]
**Trạng thái:** ✅ Done (2026-08-11)

## Bug
`PopStarGame._chipObstaclesOrFrozen()` (`pop_star_game.dart:882-889`) trừ 1
lượt Freeze mỗi lần pop khi Freeze đang hiệu lực:

```dart
if (freezeTurnsLeft > 0) {
  freezeTurnsLeft--;
  return {};
}
```

`_saveUndo()` **có** snapshot `bossHp` và `countdownRemaining` — hai state
"theo lượt" khác — nhưng bỏ sót `freezeTurnsLeft`.

### Kịch bản tái hiện
1. Dùng Freeze (booster 70 coin) → `freezeTurnsLeft = 5`.
2. Nổ 1 nhóm cạnh obstacle → còn 4.
3. Bấm Undo.
4. Bàn, điểm, `movesUsed` quay lại đúng — nhưng Freeze vẫn chỉ còn 4.

Người chơi mất 1/5 giá trị của booster 70 coin cho một nước đã hoàn tác.

## Vì sao chỉ P2
Thiệt hại giới hạn (1 lượt / 5), chỉ xảy ra khi Freeze đang bật, và Freeze
là booster ít dùng nhất. Nhưng root cause giống hệt [[X17]]/[[X20]] — snapshot
undo không đầy đủ — nên gộp cùng nhánh thì gần như miễn phí.

## User story
*As a* người chơi *I want* Undo trả lại cả lượt Freeze đã tiêu *so that*
booster tôi mua không bị đốt cho nước đi không tồn tại.

## Acceptance criteria
- [x] Freeze 5 lượt → pop 1 lần (còn 4) → Undo → `freezeTurnsLeft == 5`.
- [x] Freeze còn 1 lượt → pop (còn 0, Freeze hết) → Undo → còn 1.
- [x] Test: `test/game/undo_snapshot_test.dart`, nhóm `X21` (đặt chung với
      X17/X20 thay vì `swap_freeze_test.dart` — cả ba là cùng một khiếm
      khuyết `_saveUndo`, để chung thì người sửa tiếp thấy hết một lượt).

## Đã sửa
1. `pop_star_game.dart` — thêm `int? _undoFreezeTurns` cạnh `_undoBossHp`.
2. `_saveUndo()` — chụp `freezeTurnsLeft`.
3. `undo()` — khôi phục cùng nhịp với `bossHp`/`countdownRemaining`.

## Ghi chú kỹ thuật
Làm chung PR với [[X17]] và [[X20]]. Cả ba là **cùng một khiếm khuyết**:
`_saveUndo` snapshot theo danh sách tay, và danh sách trôi lại phía sau mỗi
khi thêm state theo lượt (power tile F5, freeze F10, counter đời I22/I50/I66).

Đã thêm doc comment ngay trên `_saveUndo` liệt kê **mọi** state phải snapshot
và vì sao, để người thêm cơ chế theo lượt thứ tư biết đúng chỗ cần đụng. Cố ý
**không** gom vào một object "GameSnapshot" — không cần abstraction cho 1 slot
undo single-step.

DoD chung: `../README.md`.
