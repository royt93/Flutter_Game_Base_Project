# X13 — Fix 4 nhóm bug: color contrast, animation, performance, memory leak

## Mục tiêu

User phản ánh trực tiếp: **"lưu ý bug color tương phản, text đọc không được,
user chửi"** và **"bug hiệu suất, bug animation, bug memory leak, animation
xấu xí"**. Audit lại toàn bộ codebase (sau X11/X12), xác nhận bằng code thật
4 nhóm bug cụ thể và sửa root cause cho từng nhóm — không vá phòng hờ cho
các phát hiện không phải bug thật (vd ListView 5-14 item, không phải nguồn
lag).

## Vì sao

App đã pivot từ theme dark-neon sang bright-casual/candy (`NeonTheme.card =
0xFFFFFFFF`), nhưng vài chỗ vẫn giữ `Colors.white` làm màu chữ từ thời
dark-theme — trên nền trắng, chữ trắng gần như vô hình. Song song, 4 widget
hiệu ứng UI (confetti, mascot, pulse-glow, coin-fly) và `level_select_screen`
chưa từng tôn trọng cờ "Giảm chuyển động" (reduce motion) dù
`pop_star_game.dart` đã có pattern gate đúng ở 2 chỗ khác — vừa là bug
accessibility vừa là bug hiệu suất (ticker chạy vô hạn dù user đã tắt hiệu
ứng). Cuối cùng, mọi lệnh phát âm thanh (đặc biệt `playMelodic`/`_arpAfter`
— chạy trên MỌI lần tap pop, hot-path nhất của game) tạo `AudioPlayer` mới
qua `FlameAudio.play()` nhưng không bao giờ `.dispose()` → leak tích luỹ
liên tục trong lúc chơi bình thường.

## Đã sửa

**Nhóm A — Color contrast (2 điểm):**
- `home_screen.dart` — Drawer title `StrokeText`: `color: Colors.white` →
  `color: NeonTheme.ink` (chữ trắng trên `Drawer(backgroundColor:
  NeonTheme.card)` trắng tinh → vô hình, chỉ còn viền magenta mỏng).
- `neon_dialog.dart` — `_DialogButton` label: `color: Colors.white` →
  `color: NeonTheme.ink` (container chỉ có border viền màu, không fill nền
  → chữ trắng vô hình trên panel dialog trắng phía sau).

**Nhóm B — Animation: Reduce Motion (5 widget):** thêm getter
`_reduceMotion` (đọc `StorageKeys.reduceMotion`) vào `confetti_overlay.dart`,
`star_mascot.dart`, `pulse_glow.dart`, `coin_fly_overlay.dart`,
`level_select_screen.dart` (`_flowCtrl`):
- Animation lặp vô hạn (`star_mascot`, `pulse_glow`, `_flowCtrl`): chỉ gọi
  `.repeat(...)` trong `initState` nếu `!_reduceMotion` — bật cờ thì
  controller giữ giá trị khởi tạo, không tốn CPU vẽ lại liên tục (đồng thời
  fix nhóm C — hiệu suất).
- Animation một lần (`confetti_overlay`, `coin_fly_overlay`): bỏ qua
  `.forward()` khi bật cờ, `build()` trả `SizedBox.shrink()` ngay;
  `coin_fly_overlay` gọi `widget.onDone?.call()` qua
  `WidgetsBinding.instance.addPostFrameCallback` để giữ đúng contract
  callback mà không cần chạy animation.

**Nhóm C — Performance:** không tìm thêm hot-path CPU đáng kể ngoài X11 đã
xử lý; việc thực chất trong nhóm này là `_flowCtrl` dừng hẳn khi
reduce-motion bật (xem Nhóm B).

**Nhóm D — Memory leak (`audio_manager.dart`):** sửa 1 điểm chốt duy nhất
`_ignoreAudio` (mọi lệnh phát âm thanh đều đi qua đây) — sau khi
`FlameAudio.play()`/`FlameAudio.bgm.play()` trả về `AudioPlayer`, lắng nghe
`onPlayerComplete.first` (timeout an toàn 5s) rồi `.dispose()`. Không cần
sửa từng call site (`playNote`, `playMelodic`, `_arpAfter`, `startBgm`, ...).

**Bug phát sinh ngoài ý muốn khi chạy smoke test bắt buộc (regression tự
gây ra, đã tự phát hiện + sửa trong cùng phiên):** sau khi thêm
`_reduceMotion` vào 5 widget trên, `flutter test --exclude-tags slow` báo
7 test fail (`star_mascot_test.dart` x4, `confetti_overlay_test.dart`,
`coin_fly_overlay_test.dart`, `pulse_glow_test.dart`) — không phải
pre-existing như nghi ngờ ban đầu, mà là regression thật: các test này
pump 4 widget hiệu ứng độc lập (không đăng ký GetX/`StorageService`), nên
`StorageService.to.getBool(...)` ném lỗi "StorageService not found" ngay
khi build → widget rỗng → mọi assertion theo sau fail domino (kể cả lỗi
"Found 0 widgets with text PLAY" ở `pulse_glow_test.dart`, chỉ là hệ quả).
Fix root-cause: thêm `StorageService.maybe` (getter an toàn, cùng pattern
với `AudioManager.maybe` đã có sẵn) — `Get.isRegistered<StorageService>() ?
Get.find<StorageService>() : null`; đổi cả 5 getter `_reduceMotion` sang
`StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false`. Giữ
nguyên `pop_star_game.dart`'s 2 chỗ gate cũ (`StorageService.to` trực tiếp)
vì luôn chạy trong context đã đăng ký service, không cần sửa.

## Acceptance criteria

- [x] `flutter analyze` → 0 issues.
- [x] `flutter test --exclude-tags slow` → 261 test xanh toàn bộ, không còn
      failure nào (kể cả 7 regression tự gây ra ở trên).
- [x] Build + chạy release trên Android emulator (`emulator-5554`):
  - [x] Drawer title đọc được rõ trên nền trắng.
  - [x] Dialog button label đọc được.
  - [x] Bật "Giảm chuyển động" → confetti/coin-fly không chạy, mascot/
        pulse-glow đứng yên, level-select không còn animation nền chạy.
  - [x] Tắt "Giảm chuyển động" → mọi animation vẫn chạy mượt như cũ (không
        regression).
  - [x] Chơi nhiều lượt pop liên tục (kể cả combo cao) → không crash/tiếng
        bị cắt bất thường do việc dispose `AudioPlayer`.

## Ghi chú

- Không sửa `stroke_text.dart` default `color: Colors.white` — đi kèm
  default `stroke: NeonTheme.ink` (tối) nên vẫn đọc được ở các call site
  đang dùng đúng (`neon_button.dart`, `neon_app_bar.dart`,
  `level_select_screen.dart:685` nền banner đặc màu). Đổi default sẽ ảnh
  hưởng ngược các chỗ đang đúng.
- Không sửa `home_screen.dart` hero title (fontSize 46, cùng pattern
  color:white/stroke:magenta) — nằm trên `NeonBg` gradient nhiều màu (không
  phải nền trắng đặc), kiểu logo casual-game phổ biến, đủ tương phản.
- Không sửa `game_screen.dart` điểm số (`color: NeonTheme.ink, stroke:
  Colors.white`) — đúng chiều chữ tối + viền sáng nổi trên nền bận, không
  phải bug.
- Audit sâu không tìm thêm hot-path CPU nào khác ngoài X11 đã xử lý; các
  phát hiện phụ (`ListView` không `.builder` ở `star_road_screen.dart`/
  `season_screen.dart`) chỉ 5-14 item, không đáng kể, cố tình không sửa để
  tránh vá phòng hờ.
