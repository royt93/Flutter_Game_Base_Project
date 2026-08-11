# X25 — `decodeReplay`/challenge code không giới hạn payload → treo/OOM UI isolate

**Epic:** E6 Hardening · **SP:** 3 · **Pri:** Should · **Mức:** P2
**Deps:** — · **Liên quan:** [[I28]] [[I37]] [[I58]] [[I42]]
**Trạng thái:** ✅ Done (2026-08-11)

## Vấn đề
`decodeReplay()` (`replay.dart:29-51`) nhận chuỗi **từ người dùng dán vào**
(màn Ghost Replay), split và materialize toàn bộ danh sách tap mà không giới
hạn độ dài chuỗi hay số tap. Mỗi tap sau đó được playback tuần tự bằng timer.

### Kịch bản tái hiện
Dán một replay base64 hợp lệ về cú pháp nhưng chứa hàng trăm nghìn entry
`0,0;0,0;...`. `decodeReplay` cấp phát chuỗi + list + record cho toàn bộ
payload **đồng bộ trên UI isolate** → treo/ANR/OOM. Nếu sống sót, playback
kéo dài theo số tap và người chơi không thoát ra được.

### Cùng lớp vấn đề, cần rà chung
Mọi codec nhận input không tin cậy đều phải bị chặn kích thước:
- `challenge_code.dart` — mã thách đấu dán từ bạn bè
- `puzzle_code.dart` — mã board Puzzle Lab, dán từ bất kỳ đâu
- `backup_code.dart` — mã backup, dán từ bất kỳ đâu (xem thêm [[X26]])

Đây là **root cause fix**: đừng chỉ vá `replay.dart`, cả 4 codec đều là
"biên tin cậy" (trust boundary) và đều thiếu guard.

## Vì sao Should
Không tự xảy ra khi chơi bình thường — cần ai đó cố tình đưa mã độc hại.
Nhưng game *khuyến khích* chia sẻ mã (share_helper, QR, challenge code), nên
đường dẫn input không tin cậy là tính năng chính, không phải ngoại lệ. Và
người chơi bị treo app sẽ báo cáo là "app hỏng", không phải "tôi bị troll".

## User story
*As a* người chơi dán mã từ bạn *I want* app từ chối mã hỏng/quá lớn một
cách gọn gàng *so that* tôi không phải force-quit.

## Acceptance criteria
- [x] Mọi decoder từ chối input dài hơn ngưỡng **trước khi** decode (kiểm
      `String.length` ở dòng đầu hàm, trước cả `base64Url.decode`).
- [x] `decodeReplay` từ chối replay vượt ngưỡng số tap.
- [x] Payload khổng lồ → `null` tức thì, UI hiện "mã không hợp lệ" đã i18n.
- [x] Mã hợp lệ bình thường vẫn decode đúng — 43 test cũ của 4 codec xanh,
      không regression.
- [x] Ngưỡng là hằng số có tên, có comment giải thích con số, đặt cạnh decoder.

## Ngưỡng đã chốt
| Hằng số | Giá trị | Căn cứ |
|---|---|---|
| `kMaxCodeLength` | 4096 | bàn lớn nhất 14×14; mã replay thật ~1KB |
| `kMaxReplayTaps` | 512 | 196 ô, mỗi tap xoá ≥2 ⇒ ~98 tap thật |
| `kMaxPuzzleSide` | 20 | editor 8..11 × 6..12; nới cho bản sau |
| `kMaxSenderNameLength` | 32 | tên hiển thị |
| `kMaxBackupCodeLength` | 64 KB | save đầy đủ ~97 key ⇒ vài KB |

## Đã sửa
1. `replay.dart` — `kMaxCodeLength` + `kMaxReplayTaps` (kiểm sau `split(';')`,
   trước khi materialize list).
2. `puzzle_code.dart` — cap chuỗi + `kMaxPuzzleSide` cho `rows`/`cols`.
3. `challenge_code.dart` — cap chuỗi cho **cả hai** codec (`CH:` và `CS:`),
   cộng `kMaxSenderNameLength`.
4. `backup_code.dart` — `kMaxBackupCodeLength` trước base64-decode và trước
   khi `AesGcm.decrypt` chạy.

**Subtask 3 (i18n) không cần làm:** rà lại thì mọi call site đã xử lý `null`
đúng và đã có chuỗi i18n — `puzzle_lab_screen.dart:113` dùng
`puzzle_lab_invalid_code`, `ghost_replay_screen.dart` set cờ `_invalid`,
`settings_screen.dart:133` xử lý import hỏng. Không thêm key mới nào, nên
`app_translations_test.dart` (22 ngôn ngữ) không bị đụng.

## Vì sao cap độ dài chuỗi KHÔNG đủ
`decodePuzzleGrid` mã hoá ô trống thành chuỗi rỗng giữa 2 dấu phẩy, nên một
mã **dưới** 4096 ký tự vẫn khai báo được board ~2000 ô → 2000 `BlockComponent`.
Đó là lý do phải có cap ngữ nghĩa (`kMaxPuzzleSide`) song song, không chỉ cap
chuỗi. Có test riêng cho đúng case này.

## Kiểm chứng — vòng 1 lộ test rỗng
Mutation-check lần đầu (gỡ cả 7 guard) chỉ làm **3/7** test đỏ. Nguyên nhân:
các test "mã quá dài" dán `'A' * 5000`, mà chuỗi đó base64-decode ra rác nên
decoder trả `null` **kể cả khi không có guard** — test xanh mà không chứng
minh được gì.

Đã viết lại: mỗi test dựng một mã **hợp lệ hoàn toàn về cú pháp** nhưng vượt
ngưỡng (đệm số 0 vào `levelId`, hoặc với backup thì encode payload 1200 key
bằng chính `encodeSecureBackupCode`). Mutation-check lại: **7/7 đỏ**.

DoD chung: `../README.md`.
