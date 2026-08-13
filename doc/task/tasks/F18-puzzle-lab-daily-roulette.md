# F18 — Puzzle Lab Daily: board tự vẽ thành thử thách hằng ngày

**Epic:** E9 Tính năng mới · **SP:** 3 · **Pri:** Could
**Deps:** — · **Mở rộng:** [[I42]] · **Tái dùng:** [[F13]]
**Trạng thái:** ✅ Done (2026-08-13)

## Vấn đề nó giải quyết
Puzzle Lab (I42) là một editor level đầy đủ: vẽ bàn, lưu tối đa 5, chia sẻ
bằng mã (`puzzle_code.dart`). Nhưng nó là **sandbox thuần** — không coin,
không sao, không unlock, không best-score. Không có lý do nào để quay lại nó
sau lần vọc đầu tiên.

Một tính năng đã xây xong, đã có màn hình, đã có codec, đang nằm không.

## Pitch
Mỗi ngày, chọn tất định **một** board từ bộ sưu tập của chính người chơi
(5 slot đã lưu + một bộ preset dựng sẵn) làm "Board hôm nay" — có mục tiêu
và thưởng như Daily Challenge.

## Vì sao độc quyền
Board hằng ngày do **chính người chơi tạo ra trước đó**. Người chơi trở thành
người thiết kế nội dung cho chính mình, ở một game không có nội dung do người
dùng tạo trên mạng.

## Vì sao Could
Rẻ nhất trong E9 (SP 3, gần như chỉ là nối dây), nhưng chỉ có ý nghĩa với
người chơi **đã** dùng Puzzle Lab — mà đó có thể là rất ít người. Cần biết
con số đó trước khi đầu tư thêm, nhưng game không có analytics.

Đề xuất: làm bộ preset trước (rẻ, ai cũng dùng được), phần "board của bạn"
sau.

## User story
*As a* người chơi đã vẽ vài board *I want* chúng quay lại làm thử thách hằng
ngày *so that* công sức thiết kế của tôi có chỗ dùng.

## Acceptance criteria
- [ ] Chọn board **tất định theo epoch-day** — cùng khuôn
      `daily_challenge.dart` / `lucky_color.dart` (`Random(seed)`, không
      `DateTime.now()` trong generator). Cùng một ngày mở app nhiều lần → cùng
      board.
- [ ] Nguồn: 5 slot đã lưu của người chơi **+** bộ preset dựng sẵn (đề xuất
      10-15 board, khai báo trong `lib/data/`).
- [ ] Người chơi chưa lưu board nào → dùng preset, tính năng vẫn hoạt động
      đầy đủ. **Đây là AC bắt buộc**, không phải fallback phụ.
- [ ] Có thưởng thật (coin + tiến độ daily quest) — khác Puzzle Lab thường.
      Ghi điểm 1 lần/ngày, dùng khuôn `canRecordDailyChallengeScore`.
- [ ] Board không giải được (người chơi vẽ bàn không đạt target) → **loại
      khỏi vòng chọn**. Cần một hàm kiểm tra khả thi; nếu quá đắt, dùng heuristic
      đơn giản (đủ ô cùng màu liền kề để đạt target) và ghi rõ giới hạn.
- [ ] Không đụng star/highScore/unlock campaign.
- [ ] i18n 22 ngôn ngữ; test tất định + test fallback preset + test loại board
      bất khả thi.

## Subtask
1. `lib/data/puzzle_presets.dart` — 10-15 board preset dạng mã
   `puzzle_code`. Làm cái này **trước**, nó là phần ai cũng dùng được.
2. `lib/logic/` — hàm chọn tất định theo epoch-day + kiểm tra khả thi.
3. `game_controller.dart` — `startPuzzleDaily()` theo khuôn
   `startDailyChallenge()`; key ghi điểm riêng.
4. Entry point ở `mode_select_screen` hoặc thẻ Home.
5. i18n + test.

## Ghi chú kỹ thuật
`startPuzzleLevel(grid)` đã tồn tại và đã bơm bàn có sẵn vào engine — task
này chủ yếu là chọn *bàn nào* và *thưởng gì*, không phải cơ chế mới.

Kiểm tra khả thi là phần rủi ro duy nhất. Nếu nó biến thành solver: **bỏ**,
và thay bằng "người chơi chỉ lưu được board đã tự chơi thắng ít nhất 1 lần" —
ràng buộc đó rẻ hơn nhiều và đạt cùng mục tiêu.

DoD chung: `../README.md`.

---

## Đã làm

- `tool/gen_puzzle_presets.dart` — sinh mã preset bằng **chính**
  `encodePuzzleGrid`, decode lại để tự kiểm. Không gõ tay base64.
- `lib/data/puzzle_presets.dart` — 12 preset (sọc ngang/dọc, ô vuông, kim
  cương, chữ thập, zigzag, góc, vòng, cột đôi, sóng, khối).
- `lib/logic/puzzle_daily.dart` (thuần) — cận trên điểm, bộ lọc bàn chơi được,
  chọn tất định theo epoch-day.
- `game_controller.dart` — `startPuzzleDaily()`, `puzzleDailyCandidateCodes`,
  `canRecordPuzzleDailyScore`, thưởng coin có trần; key riêng
  `lastPuzzleDailyDay`/`puzzleDailyScore`.
- `mode_select_screen.dart` — ô "Bàn hôm nay" trong nhóm Thử thách.

## Kiểm khả thi: cận trên, KHÔNG solver

Task ghi rõ nếu phần này biến thành solver thì bỏ. Nên dùng **cận trên**: cộng
`scoreForGroup(n)` cho từng màu, giả định mọi ô cùng màu gộp được vào một
nhóm. Đây là ước lượng **thừa**, đúng một chiều — nó không nói bàn giải được,
chỉ nói chắc chắn bàn **không** giải được khi cận trên đã dưới target. Nhờ vậy
bộ lọc không bao giờ loại nhầm bàn giải được.

Cộng thêm hai điều kiện rẻ hơn chạy trước: có gem thật, và có **ít nhất một
nước đi** ngay từ đầu (`hasAnyMovableGroup`). Preset `checker` xen kẽ hoàn
toàn chết ở điều kiện này — cố ý giữ trong bảng làm ca kiểm thử sống cho chính
bộ lọc.

## Mượn `GameMode.puzzleLab` thay vì thêm mode mới

`puzzleLab` cố ý không thưởng gì. Thêm `GameMode.puzzleDaily` bắt phải rà lại
mọi `switch (mode.value)` trong app cho một khác biệt duy nhất là "có thưởng
hay không", và làm lệch cả sweep test đếm số side mode trong
`RELEASE_CHECKLIST.md`.

Dùng cờ `puzzleDailyRun`. An toàn vì `startPuzzleLevel` là **cửa vào chung**
của mọi ván puzzleLab và nó xoá cờ — không có đường nào bật cờ mà không đi qua
đó trước. Có test riêng chốt điều này (mutation-check xác nhận).

## Kiểm chứng

- `test/logic/puzzle_daily_test.dart` — 22 ca thuần.
- `test/presentation/puzzle_daily_wiring_test.dart` — 15 ca nối controller:
  chưa lưu bàn nào vẫn chạy (AC bắt buộc), bàn tự vẽ ưu tiên trước preset, cờ
  tắt đúng lúc, trần coin, không ghi điểm hai lần/ngày, không đụng
  star/highScore/unlock, không tiêu mất lượt Daily Challenge.
- **Mutation-check 4/5 bị bắt:** bỏ kiểm có nước đi; không tắt cờ ở Puzzle Lab
  thường; bỏ trần coin; bỏ chặn ghi điểm lần hai.
- Toàn bộ suite: **1371 xanh**, `flutter analyze` 0 issue.

## Một dòng code mê tín đã gỡ

Bản đầu gieo `Random(epochDay * 7919)` kèm giải thích "Random(n) với n liền kề
cho chuỗi đầu giống nhau". Mutation-check không bắt được việc bỏ hệ số nhân,
nên **đo thật**: gieo trần epoch-day đã cho đủ 11/11 và 12/12 chỉ số khác nhau
trong 60 ngày, chuỗi lặp liên tiếp dài nhất 3 — y hệt bản có nhân.

Lời giải thích SAI. Gỡ hệ số, ghi lại số đo, và siết ca test thành "60 ngày
phủ hết mọi bàn, không lặp quá 4 ngày liền" để nó thật sự ràng buộc điều gì đó.

## Nợ đã ghi

1. Chưa có màn hình riêng cho "Bàn hôm nay" — vào thẳng ván từ ô mode. Nhãn
   "đã chơi hôm nay" đã có key i18n nhưng chưa hiển thị ở đâu.
2. i18n mới en + vi; 20 ngôn ngữ còn lại rơi về bản en.
3. ~~Chưa verify trên thiết bị thật.~~ Đã verify trên emulator: vào được từ
   ô "Board of the Day", bàn preset `corners` 9×8, Target 432 đúng công thức.
   Lần verify này lộ ra [[X32]] — chain lock rò vào bàn tự vẽ.
4. Phần "board của bạn" hoạt động nhưng chưa có gì trong app **khuyến khích**
   lưu bàn — đúng lo ngại của task khi xếp Could.
