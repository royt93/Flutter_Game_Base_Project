# X17 — Undo không rollback counter đời → farm vô hạn achievement/quest/weekly/clan

**Epic:** E6 Hardening · **SP:** 5 · **Pri:** Must · **Mức:** P1
**Deps:** — · **Cùng nhánh với:** [[X20]] [[X21]] (đều đụng `_saveUndo`)
**Trạng thái:** ✅ Done (2026-08-11)

## Mục tiêu
Undo phải hoàn tác *tất cả* hệ quả của nước đi, không chỉ điểm trên bàn.

## Bug
`GameController.registerPop()` (`game_controller.dart:2121-2148`) cộng ngay
vào các counter **vĩnh viễn**:

| Counter | Dòng | Persist ngay? |
|---|---|---|
| `totalGemsPopped` | 2132 | có (`setInt`) |
| `weeklyGoalProgress` (I50) | 2137 | có |
| `clanContribWeek` + `clanContribTotal` (I66) | 2140 | có |
| `dailyQuestProgress` (I67) | 2141 | có |
| `maxComboEver` | 2142 | có |
| achievement unlock + coin thưởng | 2146 | có |

`PopStarGame._saveUndo()` / `undo()` chỉ snapshot `colorGrid`, `lockGrid`,
`bossHp`, `countdownRemaining`, score, combo, `movesUsed`. Không counter nào
ở bảng trên được rollback.

### Kịch bản tái hiện
1. Vào bất kỳ màn nào, nổ 1 nhóm lớn (ví dụ 9 ô).
2. Bấm Undo — điểm và bàn quay về trạng thái trước.
3. Nổ lại đúng nhóm đó. Lặp N lần.

Sau N vòng: bàn và điểm không đổi, nhưng `totalGemsPopped` tăng `9×N`,
weekly goal + clan contribution tăng `9×N`, daily quest `popGems` tăng `9×N`,
và achievement theo `totalGemsPopped` unlock kèm coin thưởng.

Undo đầu mỗi màn **miễn phí** (I5, +1 nữa nếu có perk `extra_undo`), nên vòng
farm này không tốn gì ở lần đầu; sau đó vẫn rẻ hơn nhiều so với phần thưởng
thu về.

## Vì sao Must
Phá hỏng đồng thời: 28 achievement, daily quest, weekly goal (300 gem),
clan pool (2000 gem), và mọi cosmetic mở khoá theo `totalGemsPopped`
(`burst_styles.dart`) hoặc `maxComboEver` (`combo_text_styles.dart`). Nghĩa
là gần như toàn bộ hệ progression đều bơm được.

## User story
*As a* người chơi *I want* Undo trả bàn về đúng trạng thái trước nước đi
*so that* tiến độ dài hạn phản ánh thứ tôi thật sự chơi.

## Acceptance criteria
- [x] Sau `undo()`, `totalGemsPopped`, `weeklyGoalProgress`, `clanContribWeek`,
      `clanContribTotal`, `dailyQuestProgress`, `maxComboEver` đều trở về đúng
      giá trị trước nước đi bị hoàn tác.
- [x] Achievement đã unlock trong nước đi bị undo **không** bị thu hồi
      (coin đã trao rồi) nhưng **không** unlock lại lần nữa khi nổ lại — chốt
      rõ hành vi này trong test, không để mơ hồ.
- [x] Vòng lặp "nổ → undo → nổ lại" 20 lần cho ra counter đời bằng đúng 1 lần
      nổ, không phải 20.
- [x] Undo vẫn hoạt động đúng ở mọi `GameMode` có undo (bossRush đã chặn sẵn) —
      không đụng nhánh phân biệt mode, snapshot chạy ở mọi mode qua `_saveUndo`.
- [x] Test mới: `test/game/undo_snapshot_test.dart` (9 case, cover cả X20/X21).

## Đã sửa
1. `game_controller.dart` — record snapshot `_undoCounters`
   `(gems, weekly, clanWeek, clanTotal, quests, maxCombo)` + `saveUndoCounters()`
   / `restoreUndoCounters()` (khôi phục + ghi lại đĩa).
2. `pop_star_game.dart` — `_saveUndo()` gọi `controller.saveUndoCounters()`
   (dưới cùng guard `!isReplay` với `_undoScore`); `undo()` gọi
   `controller.restoreUndoCounters()` cạnh chỗ khôi phục điểm/combo.

**Đổi so với subtask kế hoạch ban đầu:** kế hoạch định chụp snapshot *trong*
`registerPop()`. Làm vậy **sai**: bomb/rainbow/swap/shuffle đều gọi `_saveUndo()`
nhưng **không** gọi `registerPop()`, nên undo sau một cú bomb sẽ khôi phục
counter về mốc của lần pop *trước đó* — trừ oan tiến độ. Vòng đời snapshot phải
gắn với `_saveUndo`, không gắn với `registerPop`. Có test riêng cho đúng case
này (`undo sau bomb không lùi nhầm counter của lần pop trước`).

[[X24]] chưa làm nên không gộp được; snapshot hiện ghi thẳng đĩa lúc restore.

## Kiểm chứng
Tạm comment `controller.restoreUndoCounters()` → 3/9 test đỏ. Test bắt được
bug thật, không phải test rỗng.

## Ghi chú kỹ thuật
Đã cân nhắc và **bỏ** đường "không cộng counter cho tới khi màn kết thúc" —
`registerPop` đang nuôi UI realtime (weekly goal card, quest dialog) và combo
layer audio. Snapshot + rollback ngắn hơn và không phá realtime.

DoD chung: `../README.md`.
