# F16 — Ghost Duel bất đồng bộ: xem ghost đối thủ chạy trên bàn của mình

**Epic:** E9 Tính năng mới · **SP:** 8 · **Pri:** Should
**Deps:** [[X25]] (giới hạn payload) bắt buộc trước
**Tái dùng:** [[I28]] replay · [[I37]] challenge code · [[I58]] seed challenge
**Trạng thái:** 📋 To Do

## Pitch
Thách bạn bằng một mã; đối thủ chơi **cùng bàn** với bạn và thấy "ghost"
của bạn nổ từng nhóm theo thời gian thực bên cạnh mình.

## Vì sao độc quyền
Cảm giác PvP thời gian thực với **zero backend**. Hạ tầng đã có ~80%:
- `replay.dart` — replay tất định (seed + danh sách tap), đã có test
- `challenge_code.dart` — mã thách đấu so điểm
- `ghost_replay_screen.dart` — đã phát lại replay ở chế độ chỉ-xem
- `daily_challenge.dart` — sinh bàn tất định từ seed

Thứ còn thiếu là **ghép chúng lại**: hiện challenge code chỉ mang *điểm số*,
còn replay chỉ chạy một mình ở màn riêng. Chưa có cái nào cho hai thứ đó
chạy cùng lúc trên cùng một bàn.

Game tap-to-pop khác hoặc là hoàn toàn đơn (không có gì để so), hoặc cần
server cho leaderboard/PvP. Đây là điểm giữa mà thể loại này chưa khai thác.

## Vì sao Should (khuyến nghị làm 1 trong 2 của E9)
Tác động xã hội cao nhất trên mỗi SP trong toàn bộ E9, và là **vòng lan
truyền duy nhất** mà game không-backend có thể có: người chơi phải gửi mã cho
người khác thì tính năng mới hoạt động.

## User story
*As a* người chơi *I want* thấy bạn mình chơi bàn này thế nào ngay khi tôi
đang chơi *so that* việc so tài có cảm giác đối đầu chứ không chỉ so con số.

## Acceptance criteria
- [ ] Mã duel gói: seed bàn + danh sách tap + điểm cuối + tên người tạo. Mở
      rộng `challenge_code.dart` hoặc `replay.dart` — **một trong hai**, không
      tạo codec thứ ba.
- [ ] Người nhận dán mã → chơi **đúng bàn đó** (bàn tất định từ seed).
- [ ] Ghost hiển thị dưới dạng lớp mờ chồng lên bàn, phát lại theo **số nước
      đi** (không phải thời gian thực) — nếu theo thời gian, người chơi chậm
      sẽ thấy ghost xong từ lâu và mất hết ý nghĩa.
- [ ] Bật/tắt ghost giữa ván; tắt là mặc định nếu người chơi đã tắt hiệu ứng
      chuyển động (`reduceMotion`).
- [ ] Kết thúc: so điểm, hiện thắng/thua/hoà, cho tạo mã trả đũa.
- [ ] Mã hỏng/quá lớn → thông báo lỗi i18n, không treo ([[X25]]).
- [ ] Chế độ này **không** đụng star/highScore/unlock campaign — nếp chung
      của mọi side-mode.
- [ ] Best score riêng, key riêng trong `StorageKeys`.
- [ ] Test: mã round-trip, tính tất định của bàn từ seed, đồng bộ ghost theo
      nước đi, mã hỏng.

## Subtask
1. Đọc kỹ `replay.dart` + `challenge_code.dart` + `ghost_replay_screen.dart`.
   Quyết định **codec nào mở rộng**, ghi lý do vào file này trước khi code.
2. Mở rộng codec (thêm điểm + tên vào payload replay là đường ngắn nhất).
3. `pop_star_game.dart` — lớp ghost. Đây là phần khó nhất: phải render trạng
   thái bàn *của ghost* chồng lên bàn *của người chơi*, và hai bàn phân kỳ
   ngay sau nước đi đầu tiên. **Chốt sớm cách trình bày**: đề xuất chỉ hiện
   *nhóm ghost vừa nổ* dạng nhấp nháy + điểm ghost chạy trên HUD, **không**
   render toàn bộ bàn ghost (rẻ hơn nhiều, và dễ hiểu hơn cho người chơi).
4. Màn hình + luồng nhập mã (tái dùng `ghost_replay_screen`).
5. i18n + test.

## Rủi ro
- **Ghost render đè lên bàn thật gây rối mắt.** Giảm bằng đường "chỉ nhấp
  nháy nhóm vừa nổ" ở subtask 3. Prototype phần này **trước** khi làm codec.
- **Replay tất định chỉ đúng ở campaign** (CLAUDE.md ghi rõ). Duel phải dùng
  bàn từ seed (như Daily Challenge), không dùng bàn campaign random.
- Nếu prototype ghost không đọc được sau 1 ngày thử: **hạ xuống "chỉ hiện
  điểm ghost chạy trên HUD"**. Vẫn giữ được phần lớn cảm giác đối đầu với
  1/3 công sức.

DoD chung: `../README.md`.
