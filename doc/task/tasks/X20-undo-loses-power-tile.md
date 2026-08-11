# X20 — Undo xoá mất `powerKind` của power tile đã có trên bàn

**Epic:** E6 Hardening · **SP:** 3 · **Pri:** Must · **Mức:** P1
**Deps:** — · **Cùng nhánh với:** [[X17]] [[X21]] · **Liên quan:** [[F5]]
**Trạng thái:** ✅ Done (2026-08-11)

## Bug
Power tile (F5) được đánh dấu **chỉ** trên component, không trên grid:

```dart
// pop_star_game.dart:873
if (kind != null) _blocks[row][col]?.powerKind = kind;
```

`colorGrid` vẫn giữ nguyên color index — không có sentinel âm nào cho power
tile (đối chiếu bảng negative-ID trong CLAUDE.md: obstacle, wildcard, magnet,
gift, ice, countdown, boss đều có band riêng; power tile thì không).

`_saveUndo()` snapshot `colorGrid`, `lockGrid`, `bossHp`, `countdownRemaining`.
`undo()` dựng lại `_blocks` từ grid → `powerKind` mặc định `null`.

### Kịch bản tái hiện
1. Nổ nhóm 5-6 ô → ô vừa tap hoá **line** power tile (giữ lại trên bàn).
2. Nổ 1 nhóm khác ở chỗ khác trên bàn.
3. Bấm Undo.
4. Ô power tile ở bước 1 trở lại thành gem màu thường — mất hẳn, không kích
   hoạt được nữa.

Nghiêm trọng hơn với **rainbow** (`≥9` ô, hiếm nhất và giá trị nhất): người
chơi phải nổ nhóm 9 ô để tạo, rồi mất trắng vì 1 lần Undo không liên quan.

## Vì sao Must
Undo là "lưới an toàn" — người chơi bấm nó khi *lỡ tay*. Đường này biến undo
thành hành động phá huỷ, đúng ngược lại kỳ vọng. Và undo đầu mỗi màn miễn
phí (I5) nên người chơi bấm khá thoải mái, va bug thường xuyên.

## User story
*As a* người chơi *I want* Undo giữ nguyên power tile tôi đã tạo *so that*
hoàn tác 1 nước sai không xoá công sức của nước trước.

## Acceptance criteria
- [x] Tạo power tile → nổ nhóm khác → Undo → power tile vẫn còn, đúng loại,
      vẫn kích hoạt được.
- [x] Undo ngay *nước tạo ra* power tile thì power tile **biến mất** (đúng, vì
      nước đó bị hoàn tác) — có test riêng.
- [x] Test: `test/game/undo_snapshot_test.dart`, nhóm `X20`.
- [ ] ~~Đúng với cả 3 `PowerTileKind`~~ — **không test riêng từng loại**:
      `powerTileKindForGroupSize` bốc theo `_rng`, ép đủ 3 loại cần điều khiển
      RNG. Fix không phân biệt loại (chụp/khôi phục nguyên `PowerTileKind?`),
      nên test 1 loại là đủ chứng minh cơ chế. Ghi rõ thay vì tick bừa.
- [ ] ~~Nhiều power tile cùng tồn tại → Undo giữ đủ cả~~ — cùng lý do: cần bàn
      preset có ≥2 nhóm lớn và 2 lượt tap không đụng nhau. Snapshot là quét
      toàn bàn nên không có nhánh riêng cho trường hợp "nhiều", rủi ro thấp.

## Đã sửa
1. `pop_star_game.dart` — thêm `_undoPowerKinds` (`List<List<PowerTileKind?>>`)
   cạnh `_undoBossHp`/`_undoCountdownRemaining`.
2. `_saveUndo()` — chụp `powerKind` toàn bộ `_blocks`.
3. `undo()` — sau `_blocks = next`, gán lại `powerKind` cho **mọi** ô từ
   snapshot, **kể cả gán `null`**. Chỉ gán ở ô có giá trị là **không đủ**:
   `undo()` tái dùng `BlockComponent` từ `pool` khớp theo màu, nên một block
   được tái dùng có thể mang theo `powerKind` cũ của ô khác cùng màu.
4. Thêm accessor công khai `powerKindAt(row, col)` — `_blocks` là private nên
   đây là đường duy nhất để test đọc được trạng thái power tile.

## Ghi chú kỹ thuật
Đã cân nhắc và **bỏ** đường band-ID âm (chi tiết dưới): power tile cần mang
**cả** màu gốc (để flood-fill) **lẫn** loại, nên vẫn phải mã hoá 2 chiều hoặc
giữ map song song — tức không thoát được, mà lại đụng `pop_detector`. Snapshot
là ~15 dòng, rủi ro gần bằng 0.

Hệ quả còn lại (chấp nhận có chủ đích): power tile vẫn là special tile duy
nhất không sống trong `colorGrid`, nên replay ([[I28]]) vẫn không tái tạo
được nó. Nếu xuất hiện bug thứ ba cùng loại thì mới đáng đổi sang band-ID.

## Ghi chú kỹ thuật
**Cân nhắc đường thay thế trước khi code:** cấp cho power tile một band ID âm
riêng (ví dụ `-1600..-1602`) như mọi special tile khác, để nó nằm trong
`colorGrid` và undo/save/replay tự đúng, không cần snapshot song song.

- *Ưu:* sửa root cause thật ("power tile là special tile duy nhất không sống
  trong grid"), tự sửa luôn [[X21]]-style bug tương lai, và làm replay
  (`replay.dart`) tái tạo đúng power tile.
- *Nhược:* đụng `pop_detector` (power tile phải vẫn flood-fill theo màu gốc,
  nên cần lưu cả màu → band phải mã hoá 2 chiều, hoặc thêm map song song),
  `block_component`, và mọi chỗ đang giả định `v < 0 ⇒ không phải gem thường`.

Diff của đường band-ID lớn hơn nhiều và rủi ro chạm `pop_detector` — **đề
xuất làm snapshot (subtask 1-3) cho X20**, và ghi lại đường band-ID như một
`ponytail:` comment cho lần refactor sau. Nếu [[X21]] + [[X20]] + bug thứ ba
cùng loại xuất hiện thì mới đáng đổi.

DoD chung: `../README.md`.
