# X19 — `resetProgress()` bỏ sót 8 key + toàn bộ `remixBest` → progress ma sau reset

**Epic:** E6 Hardening · **SP:** 3 · **Pri:** Must · **Mức:** P1
**Deps:** — · **Liên quan:** [[T4]]
**Trạng thái:** ✅ Done (2026-08-11)

## Bug
`GameController.resetProgress()` (`game_controller.dart:2484-2575`) remove
~55 key rồi gọi `_load()` ở cuối. Các key sau **không** nằm trong danh sách
remove, nên `_load()` nạp lại nguyên giá trị cũ ngay lập tức:

| Key | Hệ | Hậu quả |
|---|---|---|
| `streakFreezeCount` | I55 | token bảo vệ streak còn nguyên |
| `starDustCount` | I65 | Star Dust còn nguyên |
| `starOwnedPets` | I65 | pet còn nguyên, **vẫn tiếp tục sinh coin idle** |
| `lastPetCollectTimestampMs` | I65 | mốc idle còn nguyên |
| `starSeedCount` | I64 | Star Seed còn nguyên |
| `claimedStarSeedMask` | I64 | constellation đã claim còn nguyên |
| `activeSkyAura` | I64 | aura đang chọn còn nguyên |
| `remixBest(levelId)` ×260 | I80 | best Remix từng level còn nguyên |

Ngoài ra chưa rõ **có chủ đích hay không** (cần PO chốt, xem AC):
`bossRushBestStreak`, `savedPuzzles`, `raidBoss*` (4 key), `hasShownReviewPrompt`,
`hasSeenFtue` / `hasSeenShopTutorial` / `hasSeenBoosterTutorial` /
`hasSeenDailyChallengeTutorial`.

### Kịch bản tái hiện
1. Ấp 1 pet, tích Star Dust, claim 1 constellation, chơi 1 màn Remix.
2. Settings → Reset Progress.
3. Campaign về level 1, coin về 0 — nhưng mở Pet Habitat: pet còn đó, và bấm
   nút hốt vẫn nhận được coin idle. Sky Shrine vẫn hiện constellation đã claim.

Đây **không** phải UI stale — dữ liệu thật vẫn nằm trong `SharedPreferences`.

## Vì sao Must
"Reset Progress" là hành động phá huỷ, không hoàn tác được, và người chơi bấm
nó vì muốn *bắt đầu lại sạch*. Reset một nửa là kết quả tệ hơn cả hai lựa
chọn: người chơi mất campaign nhưng vẫn kẹt với economy cũ.

Root cause là kiểu bảo trì: `resetProgress` là **danh sách tay** phải cập
nhật mỗi lần thêm key. Round 4-8 thêm ~20 hệ mới, danh sách trôi lại phía sau.

## User story
*As a* người chơi bấm Reset Progress *I want* mọi tiến độ thật sự biến mất
*so that* tôi chơi lại từ đầu đúng nghĩa.

## Acceptance criteria
- [x] Sau `resetProgress()`, **34** key không-whitelist (không chỉ 8 như ước
      lượng ban đầu) đều trở về mặc định.
- [x] `remixBest(id)` bị xoá cho toàn bộ level — tự động, không cần vòng lặp
      riêng (xem "Đã sửa").
- [x] PO đã chốt policy, ghi thành doc comment ngay trên `keepOnReset`.
- [x] Test khẳng định tính chất tổng quát — xem dưới. **AC quan trọng nhất**,
      là thứ ngăn bug quay lại ở Round 10.

## Policy đã chốt (PO, 2026-08-11)
**Giữ lại** (18 key): cài đặt (ngôn ngữ, âm thanh ×2, haptics ×2, theme, nhắc
nhở, ghi replay), trợ năng (mù màu, giảm chuyển động, vùng chạm lớn), trạng
thái đã-xem-rồi (`hasSeen*` ×4 + review prompt), và `playerName`.

**Xoá** — mọi thứ còn lại, gồm cả `savedPuzzles`, `bossRushBestStreak`,
`raidBoss*` ×5. Board Puzzle Lab từng được cân nhắc giữ (là nội dung người
chơi tạo, cùng loại với `playerName`) nhưng PO chốt xoá.

## Đã sửa
Đảo chiều từ blacklist sang **whitelist**:
- `storage_service.dart` — thêm `allKeys()` (dùng `prefs.getKeys()`, cùng
  đường với `exportAll()` đã có sẵn vì đúng lý do này).
- `game_controller.dart` — `static const keepOnReset` (18 key, kèm comment
  phân loại) + `resetProgress()` rút từ ~60 dòng `remove` xuống **4 dòng**:
  quét `allKeys()`, bỏ qua whitelist, xoá phần còn lại.
- Vòng lặp `for id in 1..kLevelCount` xoá `highScore`/`star` **bị bỏ hẳn** —
  không còn cần: quét theo key thật phủ luôn mọi key động (`highScore(id)`,
  `star(id)`, `remixBest(id)`) mà không phải biết trước `kLevelCount`.

Rx trong bộ nhớ: `_load()` ở cuối hàm đã gán lại gần hết. Chỗ duy nhất còn
sót là `starOwnedPets` (`assignAll` nằm trong nhánh "có dữ liệu") — sửa trong
[[X18]] bằng `clear()` vô điều kiện.

## Test
`test/presentation/save_resilience_test.dart`. Assertion chính **không** phải
"key phải biến mất" — cuối `resetProgress()` có `_load()` +
`_checkLoginStreak()` + `checkDailyQuestRollover()`, chúng ghi lại 14 key với
giá trị khởi tạo (mốc tuần/mùa/ngày hiện tại). Đó là hành vi đúng.

Tính chất được kiểm: **sau reset, storage không phân biệt được với một bản cài
mới**. So `exportAll()` của profile-vừa-reset với `exportAll()` của
profile-cài-mới; mọi key khác giá trị mà không nằm trong whitelist đều là lỗi.
Tự đúng cho mọi key tương lai, không ai phải nhớ cập nhật gì.

Kèm 2 test tường minh: 15 key bản cũ bỏ sót đều về mặc định; và cài đặt +
`hasSeen*` + `playerName` được giữ.

## Kiểm chứng
Tạm thêm nhầm `starDustCount` vào `keepOnReset` (giả lập "quên phân loại key
mới") → 2 test đỏ.

DoD chung: `../README.md`.
