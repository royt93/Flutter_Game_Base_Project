# I28 — Async Ghost Replay Share

**Epic:** Social/competitive · **SP:** 8 · **Pri:** Should · **Deps:** không

## Mục tiêu
Ghi lại toàn bộ 1 ván chơi (level id, seed RNG, chuỗi tap theo thứ tự), mã
hoá thành text code chia sẻ được (giống pattern friend code); người nhận
dán code vào để **xem lại y hệt ván chơi đó** (ghost replay, chỉ xem —
không tương tác) trên chính máy họ. Yêu cầu: giải quyết **full RNG
determinism ngay** — mọi yếu tố ngẫu nhiên ảnh hưởng board trong ván ghi lại
đều phải tái tạo được y hệt từ cùng 1 seed, không giới hạn phạm vi chỉ
level không dùng RNG.

## Vì sao
Đây là tính năng "độc quyền" bổ sung cho social/competitive (bên cạnh
Friend Compare I26 vốn chỉ so số, không xem lại được cách chơi). Vì
no-backend nên replay phải tự chứa toàn bộ state cần thiết trong text code
— điều này chỉ khả thi nếu board sinh lại **deterministic tuyệt đối** từ
seed, nếu không code sẽ replay ra board khác lúc ghi và vô nghĩa.

## Acceptance criteria
- [x] `PopStarGame._rng` đổi từ `Random()` không seed sang `Random(seed)`
      — seed truyền qua constructor (mặc định sinh random seed cho ván chơi
      thường, không đổi trải nghiệm hiện tại), nhưng **luôn lưu lại seed đã
      dùng** để phục vụ replay khi cần.
- [x] Audit toàn bộ điểm dùng RNG ảnh hưởng board trong luồng chơi thường
      (colorGrid khởi tạo, mọi `_rng.nextInt(colorCount)`, `pickGiftReward
      (Random rng)`) — đảm bảo **tất cả** đi qua đúng 1 instance `_rng` đã
      seed, không còn `Random()` không seed nào rải rác ảnh hưởng kết quả
      board trong ván được ghi.
- [x] Ghi chuỗi input: mỗi tap `(row, col)` theo đúng thứ tự — chỉ ghi khi
      tính năng "ghi lại" được bật cho ván đó (không tốn bộ nhớ mọi ván mặc
      định).
- [x] Encode thành text code (base64url, theo pattern
      `lib/core/utils/friend_code.dart`): gồm `levelId`, `seed`, danh sách
      tap nén gọn; decode trả `null` (không throw) khi code hỏng/giả mạo.
- [x] Màn hình xem lại (`GhostReplayScreen`): dựng `PopStarGame` mới với
      đúng seed từ code, tự động phát lại từng tap theo thứ tự với delay cố
      định giữa các tap (không cần đúng nhịp thời gian gốc); khoá tương tác
      trong lúc phát, chỉ xem.
- [x] Test xác nhận determinism: cùng 1 seed chạy 2 lần qua logic thuần
      (`pop_detector`/`pop_collapse` + seeded `Random`) → state cuối giống
      hệt nhau, làm regression test chống RNG không xác định lọt lại.
- [x] Test round-trip encode/decode replay code (giống
      `friend_code_test.dart`): code hỏng/giả mạo → `null`, không throw.
- [x] i18n đủ 22 locale cho màn ghi/chia sẻ/xem lại.
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Ghi chú kỹ thuật
- Tiền lệ seeded Random đã có: `lib/logic/daily_challenge.dart` (dùng
  `Random(seed)` để sinh board tái lập được) — pattern để tái dùng/mở rộng.
- Tiền lệ encode/decode base64url: `lib/core/utils/friend_code.dart`
  (`encodeFriendCode`/`decodeFriendCode`, lọc ký tự phân tách, decode bọc
  `try/catch` trả `null`).
- `PopStarGame._rng` hiện dùng ở nhiều điểm rải rác trong
  `lib/game/pop_star_game.dart` — cần audit lại **toàn bộ file** khi
  implement (không chỉ các dòng đã biết trước) để không bỏ sót nguồn RNG
  nào phá determinism.
- Giới hạn cần ghi rõ trong code: `Random(seed)` của Dart core deterministic
  theo cùng 1 phiên bản thuật toán trong SDK — chấp nhận được vì toàn bộ
  user dùng chung 1 bản build/SDK version, nhưng không đảm bảo replay code
  tương thích xuyên version SDK khác nhau về lâu dài.

DoD chung: `../README.md`.
