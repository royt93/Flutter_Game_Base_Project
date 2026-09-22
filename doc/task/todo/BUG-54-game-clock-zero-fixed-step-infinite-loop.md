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
- [ ] `GameClock(fixedStep: Duration.zero)` throw ngay tại constructor, không bao giờ treo `advance()`.
- [ ] `GameClock(fixedStep: Duration(milliseconds: -1))` cũng bị chặn.
- [ ] `GameTimeController.tick()` không tăng `elapsed` khi `GameSessionPhase` là `loading`/`ready`/`won`/`lost`, chỉ chạy khi `playing`.
- [ ] Test hiện có của `game_time_controller_test.dart` vẫn pass.
- [ ] Test `--no-enable-asserts` (hoặc tương đương) xác nhận validate `fixedStep` vẫn hoạt động ở "release-like" mode.

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
