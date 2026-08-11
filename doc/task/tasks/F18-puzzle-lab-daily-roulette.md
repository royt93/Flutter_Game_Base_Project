# F18 — Puzzle Lab Daily: board tự vẽ thành thử thách hằng ngày

**Epic:** E9 Tính năng mới · **SP:** 3 · **Pri:** Could
**Deps:** — · **Mở rộng:** [[I42]] · **Tái dùng:** [[F13]]
**Trạng thái:** 📋 To Do

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
