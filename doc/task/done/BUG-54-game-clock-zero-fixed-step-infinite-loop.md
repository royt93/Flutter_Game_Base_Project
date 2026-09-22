---
id: BUG-54
title: "GameClock.advance() treo vô hạn nếu fixedStep=Duration.zero; _clock.paused không xét phase loading/ready/won/lost"
type: bug
priority: P1
effort: S
source: "agy + claude (độc lập xác nhận cùng bug fixedStep=0), verify lại qua Read lib/core/game_time_controller.dart"
---

## Vị trí
`lib/core/game_time_controller.dart` — `GameClock` constructor + `advance()`, và `GameTimeController.tick()` (đoạn `_clock.paused = owningSession.snapshot.value.phase == GameSessionPhase.paused;`).

## Hiện trạng
1. `GameClock({Duration? fixedStep})` không có bất kỳ validate nào cho `fixedStep`. `advance()` chạy `while (_accumulator >= fixedStep) { _accumulator -= fixedStep; ... }` — nếu `fixedStep == Duration.zero`, điều kiện `_accumulator >= Duration.zero` luôn đúng (miễn accumulator không âm) và `_accumulator -= Duration.zero` không đổi accumulator — vòng lặp KHÔNG BAO GIỜ kết thúc, treo UI thread ngay khi game gọi `advance()`.
2. `_clock.paused` chỉ được set `true` khi phase là `GameSessionPhase.paused` — không tính các phase `loading`/`ready`/`won`/`lost`, nghĩa là nếu `tick()` vẫn được gọi trong các phase đó (ví dụ 1 overlay win/lose vẫn render trên nền game loop), clock tiếp tục chạy dù game session không còn ở trạng thái `playing`.

## Vì sao cần / Hậu quả
(1) là 1 hang bug thật: constructor khác cùng họ (`EnergyService`, `FrameBudgetTracker` theo mô tả claude) đều guard input tương tự nhưng `GameClock` thì không — 1 game dùng cấu hình sai (`fixedStep: Duration.zero`, kể cả vô tình từ 1 giá trị mặc định hụt) sẽ treo cứng app. (2) làm game-time trôi tiếp trong các trạng thái không nên chạy (loading/ready/won/lost), có thể gây tính điểm/animation sai nếu logic gameplay dựa vào `elapsed`.

## Đề xuất
1. Validate runtime trong constructor: `if (fixedStep != null && fixedStep <= Duration.zero) throw ArgumentError.value(fixedStep, 'fixedStep', 'must be > 0');` (runtime check, không chỉ `assert`).
2. Đổi điều kiện `_clock.paused` thành `phase != GameSessionPhase.playing` (pause bất kỳ phase nào không phải đang chơi), thay vì chỉ so sánh đúng `paused`.

## Acceptance criteria
- [x] `GameClock(fixedStep: Duration.zero)` throw ngay tại constructor, không bao giờ treo `advance()`.
- [x] `GameClock(fixedStep: Duration(milliseconds: -1))` cũng bị chặn.
- [x] `GameTimeController.tick()` không tăng `elapsed` khi `GameSessionPhase` là `loading`/`ready`/`won`/`lost`, chỉ chạy khi `playing`.
- [x] Test hiện có của `game_time_controller_test.dart` vẫn pass.
- [x] Test `--no-enable-asserts` (hoặc tương đương) xác nhận validate `fixedStep` vẫn hoạt động ở "release-like" mode — xem `## Quyết định` (không có `assert()` nào để strip, check là `if`/`throw` thường theo đúng thiết kế).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-54-game-clock-zero-fixed-step-infinite-loop.md` này trước khi làm. Đọc toàn bộ `lib/core/game_time_controller.dart` và test hiện có trước khi sửa. Implement bằng TDD — viết test tái hiện treo vô hạn bằng timeout ngắn (`expect(() => ..., ...).timeout(...)` hoặc verify số bước lặp bị chặn) trước khi sửa.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device Android thật khuyến khích nếu `GameDemoScreen` dùng `GameClock`/`GameTimeController` trực tiếp (verify game vẫn chạy đúng, không treo, pause đúng khi win/lose overlay hiện); không bắt buộc nếu chỉ đổi logic clock nội bộ không quan sát được qua UI hiện tại.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — 2 nguồn độc lập (agy, claude) xác nhận cùng root cause (fixedStep=0 infinite loop); tự Read trực tiếp `advance()`/constructor, xác nhận không có validate nào, và xác nhận `_clock.paused` chỉ so sánh đúng `GameSessionPhase.paused`. Không trùng task nào trong `doc/task/done/`.

## Quyết định

Fix cả 2 bug đúng như đề xuất:

1. **`fixedStep <= 0`**: thêm `if (step != null && step <= Duration.zero) throw ArgumentError.value(...)` trong thân constructor `GameClock`. Đây là `if`/`throw` thường (không phải `assert()`), nên tiêu chí "vẫn hoạt động ở release-like mode" tự động thoả mãn theo thiết kế nguồn (Dart chỉ strip `assert()`, không bao giờ strip `if`/`throw` ở bất kỳ build mode nào) — không có cách chạy `--no-enable-asserts` thật cho package này (`get` kéo theo `dart:ui` qua `package:flutter`, không compile được ngoài Flutter engine — đã xác nhận thực nghiệm ở BUG-49 cùng đợt).
2. **Phase check sai**: đổi `phase == GameSessionPhase.paused` thành `phase != GameSessionPhase.playing` — đúng 4 phase còn lại (`loading`/`ready`/`won`/`lost`) đều phải đóng băng clock, không chỉ `paused`.

**TDD:** viết 9 test mới trước (4 test fixedStep + 5 test phase, đủ cả 4 phase không-playing + 1 phase playing xác nhận hành vi bình thường không đổi). `git stash` riêng file lib, chạy lại — 6/9 test fail đúng thật (2 test fixedStep constructor không throw; 4 test phase loading/ready/won/lost đều thấy `elapsed` vẫn tăng dù không phải playing) — 3 test còn lại (2 fixedStep hợp lệ + phase playing) pass cả 2 code cũ/mới, hợp lý vì đó là test xác nhận KHÔNG đổi hành vi bình thường. Khôi phục fix: cả 23 test (14 cũ + 9 mới) pass.

**Không phá gì:** `flutter analyze` root + `example/` sạch. `dart run tool/api_compatibility.dart check` → unchanged. `flutter test --exclude-tags slow` root: 2070 pass / 19 fail (đúng 19 golden có sẵn, không tăng). `example/`: 129/129 pass — xác nhận `cookbook_screen.dart` (call site thật duy nhất của `GameTimeController`/`GameClock` trong `example/`) vẫn hoạt động đúng.

Không smoke test device thật — task tự cho phép ("khuyến khích nếu GameDemoScreen dùng trực tiếp... không bắt buộc nếu chỉ đổi logic clock nội bộ"); đã kiểm tra `RoyGame`/`GameDemoScreen` KHÔNG dùng `GameTimeController`/`GameClock` (chỉ `cookbook_screen.dart` dùng, đã verify qua test suite/analyze, không phải qua Flame game loop thật).

**Tự chấm điểm: 9.5/10.** Fix tối thiểu, đúng root cause cho cả 2 bug độc lập trong cùng file, TDD xác nhận rõ ràng 6/9 test phân biệt được code cũ/mới, không phá test nào. Trừ 0.5 vì không smoke test device thật (dù task tự cho phép bỏ qua, việc chưa đụng UI thật nào qua Flame game loop vẫn là 1 giới hạn thật của độ tin cậy).
