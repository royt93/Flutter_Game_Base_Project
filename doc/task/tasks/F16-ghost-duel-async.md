# F16 — Ghost Duel bất đồng bộ: xem ghost đối thủ chạy trên bàn của mình

**Epic:** E9 Tính năng mới · **SP:** 8 · **Pri:** Should
**Deps:** [[X25]] (giới hạn payload) bắt buộc trước
**Tái dùng:** [[I28]] replay · [[I37]] challenge code · [[I58]] seed challenge
**Trạng thái:** ✅ Done (2026-08-13) — **bản rút gọn có chủ ý, xem dưới**

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

---

## Subtask 1: chọn mở rộng `replay.dart`

Duel cần **danh sách tap** — chỉ `replay.dart` có. `challenge_code.dart` chỉ
mang điểm số; thêm taps vào đó là dựng lại replay lần thứ hai. AC cấm codec thứ
ba nên dùng đúng nhà của taps.

Khác `ReplayData` ở một điểm quan trọng: `DuelData` mang **seed**, không mang
`levelId`. Replay tất định chỉ đúng ở campaign (bàn campaign sinh ngẫu nhiên
mỗi lần chơi) — đúng rủi ro task đã ghi. Duel dựng bàn từ seed như Daily
Challenge, nếu không hai người chơi hai bàn khác nhau và so điểm là vô nghĩa.

## Rút gọn có chủ ý: ghost trên HUD, KHÔNG render lớp ghost trên bàn

Task cho sẵn đường lùi: *"Nếu prototype ghost không đọc được: hạ xuống chỉ hiện
điểm ghost chạy trên HUD. Vẫn giữ được phần lớn cảm giác đối đầu với 1/3 công
sức."* Đã chọn đường đó ngay từ đầu, vì hai bàn phân kỳ ngay sau nước đi đầu
tiên nên "nhóm ghost vừa nổ" nhấp nháy trên bàn **của người chơi** trỏ vào ô đã
không còn tồn tại — rối mắt và sai.

Điểm ghost chạy theo **số nước đi** (không theo thời gian): người chơi chậm mà
thấy ghost về đích từ lâu thì hết ý nghĩa đua.

## Điểm ghost lấy ở đâu

Mã duel chỉ mang điểm CUỐI. Muốn HUD hiện điểm ghost tại nước thứ N thì phải
biết đường đi của nó — nội suy tuyến tính từ điểm cuối là nói dối. Nên
`ghost_duel.dart` **mô phỏng lại** lượt chơi bằng chính máy logic thuần đã có
(`findConnectedGroup` + `applyGravityAndCollapse` + `scoreForGroup`).

**Giới hạn có chủ ý:** mô phỏng bỏ qua power tile, booster, combo multiplier.
Điểm mô phỏng là **cận dưới**. Vì vậy phần so thắng-thua luôn dùng
`DuelData.score` (con số thật), còn đường điểm theo nước chỉ để tạo cảm giác
đua. Có test riêng chốt điều này, và mutation "so bằng điểm mô phỏng" bị bắt.

## Kiểm chứng

- `test/logic/ghost_duel_test.dart` — 30 ca: codec round-trip, tên chứa `|`,
  mã hỏng/quá dài/quá nhiều tap ([[X25]]), bàn tất định từ seed, mô phỏng
  (điểm không giảm, tap ngoài bàn không ném, **không sửa bàn gốc**, tất định).
- `test/presentation/duel_wiring_test.dart` — 15 ca: bàn từ seed, điểm ghost
  theo số nước, giữ điểm cuối khi người chơi đi dài hơn, **không** đụng
  star/highScore/unlock, best score key riêng chỉ tăng.
- **Mutation-check 4/4 bị bắt.**
- `RELEASE_CHECKLIST.md` cập nhật 14 → 15 side mode (sweep test bắt đúng lúc).
- Verify trên Pixel 7 Pro: dán mã → "đấu với Roy1 / Điểm cần vượt: 640" →
  vào ván, bàn 9×8 từ seed, HUD hiện "Bóng ma: 0".
- Toàn bộ suite: **1482 xanh**.

## Ghi chú khi verify: `adb input text` làm hỏng mã

Mã bị từ chối hai lần trên máy. Đọc lại ô nhập bằng `uiautomator dump` thì thấy
`OCww` thành `OCw` — **bàn phím Telex tiếng Việt** nuốt `ww` thành `ư`. Tắt IME
thì mã khớp và chạy đúng. Lỗi công cụ test, không phải sản phẩm — nhưng đáng
ghi lại vì mọi lần verify mã dán sau này đều sẽ vấp.

## Trả nợ UI (cùng ngày)

- **Băng kết quả** trong dialog kết thúc: thắng/thua/hoà + tỉ số
  `điểm bạn - điểm ghost`. Đặt **trước** banner challenge/seed-challenge vì khi
  đang đấu ghost thì đó là thứ người chơi quan tâm nhất.
- **Nút "Chép mã trả đũa"** — cùng seed, mang lượt chơi và điểm của người vừa
  chơi. Chỉ hiện khi `buildRematchCode()` thật sự dựng được mã.

### Lỗi bố cục do chính lần này gây ra

Bản đầu để nguyên cụm chữ `Bóng ma: 330` trên thanh HUD. Trên Pixel 7 Pro nó
ăn hết bề ngang và đẩy **điểm số xuống 3 dòng** (`2.` / `85` / `0`). Thu gọn
còn icon + số. Đây là loại lỗi chỉ nhìn trên máy mới thấy — test widget dựng ở
kích thước rộng hơn nên không bao giờ đỏ.

### Va chạm tên với Pass-and-Play (I59) — hai lần

`I59` đã chiếm cả `duel_*` (i18n) lẫn `DuelOutcome` (enum). Lần đầu làm map
const không dựng được, lần hai làm `game_screen.dart` không import nổi cả hai.
Đã đổi thành tiền tố `ghost_duel_` và `GhostDuelOutcome`. Ai thêm thứ gì tên
"duel" nữa nên kiểm trước.

## Nợ đã ghi

1. **Không có lớp ghost trên bàn** — đã giải thích ở trên, đây là đường lùi
   task cho phép chứ không phải thiếu sót âm thầm.
2. Nút bật/tắt ghost giữa ván và mặc-định-tắt theo `reduceMotion`: **chưa làm**
   (không có gì để tắt khi ghost chỉ là một dòng chữ trên HUD).
3. ~~Màn kết thúc chưa hiện thắng/thua/hoà và nút tạo mã trả đũa.~~ Đã nối
   (xem "Trả nợ UI"). Băng kết quả và nút trả đũa **chưa verify tận mắt** trên
   máy — chơi hết ván bằng tap mù không tin cậy được, phần này mới chỉ có test.
4. i18n mới en + vi. Tiền tố `ghost_duel_` vì `duel_*` đã thuộc Pass-and-Play
   (I59) — trùng key làm cả map const không dựng được.
