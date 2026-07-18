# I37 — Async Challenge Code (thách đấu điểm số qua mã)

**Epic:** Social/competitive · **SP:** 5 · **Pri:** Should · **Deps:** không

## Mục tiêu
Cho phép người chơi tạo 1 "mã thách đấu" sau khi chơi xong 1 màn campaign
(mã hoá `levelId` + điểm đạt được, tương tự cơ chế `encodeReplay` của `I28`
nhưng KHÔNG kèm replay đầy đủ — chỉ điểm số), gửi cho bạn bè (share text/QR
như `I28`/`F15` đã làm). Người nhận nhập mã → chơi lại đúng `levelId` đó,
kết quả so trực tiếp với điểm trong mã (không cần replay bàn/RNG, không cần
board giống hệt).

## Vì sao
`I28` (Ghost Replay Share) đã giải quyết "xem lại y hệt ván đấu", nhưng đó là
trải nghiệm xem thụ động. `I37` là biến thể "thi đấu" — người nhận tự chơi
lại chính level đó (board mới random theo seed riêng của họ, đúng luật chơi
bình thường) và so điểm, nhẹ hơn hẳn vì không cần đảm bảo RNG determinism
xuyên suốt cả ván, tận dụng đúng hạ tầng encode/decode + share đã có ở `I28`.

## Acceptance criteria
- [ ] `lib/logic/challenge_code.dart` (mới, độc lập với `replay.dart` — không
      tái dùng chung 1 class vì payload khác hẳn): class `ChallengeCode`
      (`levelId`, `score`, `senderName`), hàm `encodeChallengeCode(ChallengeCode)`
      / `decodeChallengeCode(String)` theo đúng pattern base64url +
      delimiter `|` như `encodeReplay`/`decodeReplay` (`lib/logic/replay.dart`),
      trả `null` nếu decode lỗi format/level không tồn tại (`levelId` ngoài
      `1..kLevelCount`).
- [ ] UI màn kết quả thắng: nút "Thách đấu bạn bè" tạo
      `ChallengeCode(levelId: currentLevel.id, score: score.value, senderName:
      playerName.value)`, share qua cùng cơ chế `Share`/QR đã dùng ở `I28`
      (tái dùng widget/luồng share, không viết lại).
- [ ] UI màn nhập mã (tái dùng hoặc mở rộng màn nhập mã Ghost Replay của
      `I28` — thêm phân biệt 2 loại mã bằng prefix hoặc field discriminator
      trong payload để 1 ô nhập chung nhận diện đúng loại mã, tránh 2 màn
      nhập riêng biệt gây rối): decode thành công → hiện tên người gửi + điểm
      cần vượt, có nút "Chơi ngay" mở đúng `currentLevelRx = kLevels[levelId - 1]`
      bình thường (KHÔNG dùng `presetGrid`/`isReplay` — board random như chơi
      thường).
- [ ] Sau khi hoàn thành màn được thách đấu: so điểm đạt được với
      `challenge.score`, hiện kết quả thắng/thua thách đấu (không ảnh hưởng
      `checkEnd`/coin/star bình thường — chỉ là 1 lớp hiển thị so sánh thêm).
- [ ] i18n đủ 22 locale cho toàn bộ text mới (nút thách đấu, màn kết quả so
      điểm, thắng/thua).
- [ ] Test pure: `encodeChallengeCode`/`decodeChallengeCode` round-trip đúng;
      mã hỏng/base64 sai format → `null`; `levelId` ngoài phạm vi hợp lệ →
      `null`; tên người gửi có ký tự đặc biệt (dấu `|`, unicode tiếng Việt)
      vẫn encode/decode đúng (escape hoặc validate phù hợp).
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- KHÔNG tái dùng chung `ReplayData`/`encodeReplay` — payload và mục đích khác
  hẳn (điểm số đơn thuần vs replay đầy đủ RNG-deterministic); dùng chung sẽ
  ép thêm field thừa (`taps`, `seed`) không cần thiết cho use-case này.
- `senderName` là text tự do người chơi nhập (`GameController.playerName`,
  xem `StorageKeys.playerName`) — phải escape ký tự `|` trước khi ghép chuỗi
  encode để không vỡ định dạng decode (tiền lệ: `encodeReplay` dùng dấu `|`
  làm delimiter cố định 3 phần, không có text tự do nào chứa `|` trong đó).

DoD chung: `../README.md`.
