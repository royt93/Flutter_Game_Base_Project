---
id: BUG-91
title: "Demo pause không dừng Flame engine"
type: bug
priority: P0
effort: M
source: "fork audit core + verify phiên chính"
---

## Vị trí

`example/lib/screens/game_demo_screen.dart:405` FAB pause; `lib/presentation/game/roy_game.dart:215` `BouncingOrb.update`.

## Hiện trạng

FAB chỉ gọi `_session.pause(GamePauseReason.user)`. Không có `pauseEngine`/`resumeEngine` anywhere trong game demo; Flame vẫn tick `BouncingOrb.update`, orb chạy dưới overlay pause.

## Vì sao cần / Hậu quả

Pause UI nói game dừng nhưng simulation vẫn chạy. Collision/timer/gameplay thực sẽ sai và user mất tin tưởng.

## Đề xuất

Một helper duy nhất đồng bộ `GameSessionController` + Flame engine (`pauseEngine`/`resumeEngine`); PauseOverlay callback dùng cùng helper.

## Acceptance criteria

- [x] Widget/device test: pause → orb/world đứng yên.
- [x] Resume → orb/world chạy lại.
- [x] User và system pause giữ đúng pause reason, engine chỉ resume khi mọi reason đã hết.

## Quyết định

Thêm `ever<GameSessionSnapshot>(_session.snapshot, ...)` listener trong
`_GameDemoScreenState.initState()`, đồng bộ `_game.pauseEngine()`/
`resumeEngine()` theo THAY ĐỔI PHASE thay vì theo hành động gọi
pause/resume. Chọn hướng này thay vì helper method vì
`GameSessionController.onInit()` tự đăng ký lifecycle hook gọi
`pause/resume(GamePauseReason.system)` trực tiếp — một helper đặt ở
`GameDemoScreen` (chỉ FAB gọi tới) sẽ bỏ sót đúng nhánh system-pause (app
background) mà bug này quan tâm nhất. Tiền lệ pattern `ever()`/`Worker`
cùng dạng đã có ở `lib/presentation/widgets/shader_ticker_layer.dart`.
Worker dispose TRƯỚC `Get.delete<GameSessionController>` trong `dispose()`.

Test mới: `test/presentation/game/roy_game_test.dart` (group `BUG-91`) xác
nhận Flame's `pauseEngine()`/`resumeEngine()` tự đóng băng/chạy lại orb độc
lập; `example/test/game_demo_screen_test.dart` mở rộng test FEAT-53 lấy
instance `RoyGame` thật qua `GameWidget<RoyGame>.game!`, assert
`game.paused` + orb frozen sau tap pause FAB, chạy lại sau Resume.

Device smoke test thật trên TECNO KJ7 (`115333744A005844`, qua
`example/integration_test/app_boot_test.dart`, test
`BUG-91/BUG-92: GameDemoScreen pause FAB dừng Flame engine thật trên
device, Resume chạy lại`): build+install thành công, mở GameDemoScreen
thật, tap pause FAB → `game.paused == true` + orb đứng yên qua 1s, tap
Resume → `game.paused == false` + orb di chuyển lại qua 1s. `All tests
passed!`, không exception/warning trong log.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root và
`example/`.

Tự chấm: 9.5/10.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify FAB dòng 405 chỉ pause session, grep không thấy `pauseEngine`/`resumeEngine`, `BouncingOrb.update` dòng 215 luôn đổi position.
