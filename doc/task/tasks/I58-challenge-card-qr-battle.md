# I58 — Challenge Card QR Battle

**Epic:** Meta/retention (viral) · **SP:** 5 · **Pri:** Could
· **Deps:** I37 (Async Challenge Code)

## Mục tiêu

Mở rộng challenge code (I37) thành ảnh "thẻ thách đấu" có mã QR — bạn bè
quét QR trực tiếp (không cần gõ tay) để nhận đúng seed bàn chơi và thi
đấu so điểm, không cần backend/mạng.

## Vì sao

I37 đã có encode/decode challenge code dạng text (levelId+score+
senderName) nhưng chỉ dùng để dán/copy — chưa mang seed bàn chơi (chỉ
mang kết quả để so điểm) và chưa có kênh quét trực tiếp offline giữa 2
máy ngồi cạnh nhau.

## Acceptance criteria

- [ ] Thêm dependency sinh QR (vd `qr_flutter`) vào `pubspec.yaml` — hiện
  chưa có package QR nào trong project; ưu tiên phương án ít dependency
  nhất đáp ứng acceptance (chỉ cần vẽ QR để share ảnh, không bắt buộc
  scan-trong-app nếu quét bằng camera hệ thống + nhập code thủ công đủ
  đáp ứng).
- [ ] `ChallengeCode` (`lib/logic/challenge_code.dart` dòng 8-18) giữ
  nguyên không sửa (tránh phá I37 đang chạy) — thêm codec mới song song,
  vd `ChallengeSeedCode { levelId, seed, senderName }` +
  `encodeChallengeSeedCode`/`decodeChallengeSeedCode` dùng prefix riêng
  (vd `'CS:'`) để phân biệt với `'CH:'` hiện có.
- [ ] Bàn chơi thách đấu dùng seed sinh qua `generateDailyChallengeGrid(seed,
  ...)` (`lib/logic/daily_challenge.dart` dòng 13-22) — seed chọn ngẫu
  nhiên tại thời điểm tạo thẻ (khác Daily Challenge dùng seed theo ngày).
- [ ] Widget hiển thị thẻ thách đấu (ảnh + QR) — tái dùng
  `ShareHelper.shareBoardImage`/`captureBoardPng` pattern
  (`lib/core/share_helper.dart` dòng 21-87) để xuất ảnh, nhúng QR vào
  layout.
- [ ] Màn nhận: quét QR hoặc nhập code thủ công (theo pattern
  `ghost_replay_screen.dart` dòng 53-82) → giải mã `ChallengeSeedCode` →
  bắt đầu ván chơi qua `generateDailyChallengeGrid(seed)` + pattern
  `startPuzzleLevel(grid)` (`game_controller.dart` dòng 1175-1197) → sau
  khi chơi xong so điểm với điểm gốc trong thẻ.
- [ ] Không bắt buộc thêm `GameMode` mới nếu tái dùng được cơ chế
  `puzzleLab`-style synthetic `PopLevel` — chỉ thêm cờ phân biệt nguồn để
  UI hiển thị đúng, không lẫn với Puzzle Lab thật.
- [ ] Unit test mở rộng `test/logic/challenge_code_test.dart`:
  encode/decode `ChallengeSeedCode` round-trip đúng; cùng seed sinh grid
  giống hệt giữa 2 lần gọi (determinism).
- [ ] i18n toàn bộ text màn tạo/nhận thẻ thách đấu, đủ 22 locale.
- [ ] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
  toàn bộ.

## Ghi chú kỹ thuật

- Không sửa `ChallengeCode`/`encodeChallengeCode` hiện có (I37 đang chạy
  ổn định) — thêm codec song song với prefix khác để tránh nhầm lẫn khi
  decode.
- `generateDailyChallengeGrid` đã là pure function nhận seed tuỳ ý (không
  bắt buộc epoch-day) — dùng thẳng, không viết generator riêng.
- Nếu camera in-app scan phát sinh quá nhiều việc ngoài phạm vi SP=5,
  giảm scope xuống "share ảnh QR + màn nhập code thủ công" (quét bằng
  camera hệ thống rồi copy code vào app) — ghi rõ quyết định cụ thể khi
  triển khai.

DoD chung: `../README.md`.
