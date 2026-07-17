# I26 — Social/friend feature: Friend Code Compare (task #18)

**Epic:** Feature mới · **SP:** 3 · **Pri:** Could · **Deps:** không (local-only, không backend)

## Mục tiêu
Feature "so tài bạn bè" hoàn toàn local-only — không backend, không định
danh thật, không network. Người chơi có tên hiển thị (`playerName`), tạo mã
text mã hoá tổng sao + xu, chia sẻ mã qua pipeline share có sẵn; bạn bè dán
mã nhận được vào màn so sánh để xem ai đang dẫn trước.

## Vì sao
Task #18 yêu cầu 1 social/friend feature nhưng project chủ trương
"không backend" (xem `CLAUDE.md`) — không có server để lưu danh sách bạn
bè/leaderboard thật. Giải pháp mã hoá state thành text (base64url) tái dùng
đúng nguyên tắc "tái dùng trước khi phát minh": `share_helper.dart` đã có
pipeline share chung (comment gốc "không tạo hàm/plugin share riêng ở nơi
khác"), nên feature này chỉ thêm 1 lớp encode/decode thuần Dart + 1 màn
hình dùng lại pipeline đó — không thêm dependency, không thêm mechanic mạng.

## Acceptance criteria
- [x] `lib/core/utils/friend_code.dart`: `encodeFriendCode({name, totalStars,
      coins})` → base64url của `name|totalStars|coins` (tên bị lọc bỏ `|`
      để không lệch cột khi decode). `decodeFriendCode(code)` → trả
      `FriendCodeData?`, `null` (không throw) khi mã sai định dạng/thiếu
      cột/số âm/tên rỗng.
- [x] `StorageKeys.playerName` (`storage_service.dart`) — tên hiển thị lưu
      riêng, **không** bị xoá trong `resetProgress()` (không phải progress
      game).
- [x] `GameController`: field `playerName` (Rx, load ở `_load()`),
      `setPlayerName(name)` (trim + persist), `myFriendCode()` (đóng gói
      `playerName` + `totalStars` + `coins` hiện tại qua `encodeFriendCode`).
- [x] `FriendCompareScreen` (`lib/presentation/screens/friend_compare_screen.dart`)
      — ô nhập tên (đồng bộ 2 chiều với `playerName`), nút chia sẻ mã qua
      `shareText()` có sẵn, ô dán mã bạn bè + nút so sánh, kết quả hiển thị
      hơn/kém/hoà theo số sao chênh lệch.
- [x] Entry point: drawer Home Screen (`home_screen.dart`), icon
      `people_alt_rounded` màu teal, giữa Leaderboard và Season Pass.
- [x] i18n đủ 22 locale: 12 key mới (`friend_compare_title`,
      `friend_your_name_label/hint`, `friend_share_code_button`,
      `friend_share_message`, `friend_paste_code_label/hint`,
      `friend_compare_button`, `friend_invalid_code`,
      `friend_result_ahead/behind/tie`) — en/vi ở `_extraEn`/`_extraVi`, 20
      ngôn ngữ còn lại ở `_w38ByLang`, wired vào merge `keys` getter.
- [x] Test thuần `test/core/utils/friend_code_test.dart`: round-trip
      encode→decode, tên chứa `|` bị lọc, tên rỗng → null, base64 sai →
      null (không throw), số âm (mã giả mạo tay) → null.
- [x] `flutter analyze` 0 issues; `flutter test --exclude-tags slow` xanh
      toàn bộ.

## Rà soát checkbox (2026-07-17)
Grep xác nhận: `encodeFriendCode`/`decodeFriendCode`
(`lib/core/utils/friend_code.dart`) lọc `|` khỏi tên qua
`replaceAll('|', ' ')`, decode bọc `try/catch` trả `null` thay vì throw.
`StorageKeys.playerName = 'player_name'` (`storage_service.dart:12`) không
xuất hiện trong danh sách key bị xoá của `resetProgress()`
(`game_controller.dart`). `FriendCompareScreen` dùng `shareText()`
(`share_helper.dart`) — không có pipeline share thứ hai. Drawer entry xác
nhận tại `home_screen.dart` giữa 2 tile Leaderboard/Season Pass.
`app_translations.dart`: 12 key có mặt ở `_extraEn`, `_extraVi`, và
`_w38ByLang` (20 locale), có spread `...?_w38ByLang[e.key],` trong `keys`
getter. Smoke test: `flutter analyze` → 0 issues; `flutter test
--exclude-tags slow` → toàn bộ xanh (bao gồm 6 test case mới trong
`friend_code_test.dart`).

## Subtasks (gợi ý file)
1. `lib/core/utils/friend_code.dart` — encode/decode thuần Dart.
2. `lib/core/storage_service.dart` — `StorageKeys.playerName`.
3. `lib/presentation/controllers/game_controller.dart` — field/setter/
   `myFriendCode()`/load.
4. `lib/presentation/screens/friend_compare_screen.dart` — màn hình mới.
5. `lib/presentation/screens/home_screen.dart` — entry drawer.
6. `lib/core/app_translations.dart` — 12 key × 22 locale.
7. `test/core/utils/friend_code_test.dart` — test thuần.

## Ghi chú kỹ thuật
Không có khái niệm "danh sách bạn bè" hay lưu trữ nhiều mã đã nhận — mỗi
lần so sánh là stateless (dán mã → xem kết quả → thôi), đúng tinh thần
"local-only, không backend" mà không cần thêm bảng lưu trữ nào. Không thêm
màn hình riêng cho "lịch sử so tài" vì task không yêu cầu và sẽ là scope
creep so với "compare 1 lần". `NeonTheme.ink/inkSoft/card/cardAlt` là getter
phụ thuộc theme-mode (không phải `const`) nên các `TextStyle`/
`InputDecoration` dùng chúng phải bỏ `const`; các màu cố định như
`NeonTheme.red/teal/blue/lime/orange/gold` vẫn là `static const Color` nên
dùng được trong context `const`.

DoD chung: `../README.md`.
