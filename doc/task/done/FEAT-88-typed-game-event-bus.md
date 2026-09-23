---
id: FEAT-88
title: "Typed game-event bus nối Flame gameplay events với economy/progression/analytics — hiện phải tự nối tay từng chỗ"
type: feature
priority: P1
effort: L
source: "codex (độc lập)"
---

## Vị trí
Mới — cầu nối giữa `lib/presentation/game/roy_game.dart`/Flame `Component` events và các service nghiệp vụ (`EconomyWallet`, `PlayerProgressionService`, `AnalyticsProvider`, `AchievementService`).

## Hiện trạng
Kit có đầy đủ service nghiệp vụ (economy, progression, achievement) VÀ Flame integration (`RoyGame`), nhưng không có 1 lớp trung gian typed kết nối "sự kiện gameplay xảy ra trong Flame world" (ví dụ: entity bị tiêu diệt, level hoàn thành, combo đạt ngưỡng) với các service nghiệp vụ đó — mỗi consumer phải tự viết code nối tay từ Component callback sang service call, dễ quên 1 nhánh (ví dụ quên log achievement khi thêm 1 loại sự kiện mới).

## Vì sao cần / Hậu quả
Thiếu lớp trung gian này khiến việc "thêm 1 loại sự kiện gameplay mới cần cả economy VÀ progression VÀ achievement VÀ analytics đều biết" trở thành 4 chỗ sửa rời rạc, dễ sót — đúng loại lỗi tích hợp phổ biến nhất khi game phát triển thêm tính năng.

## Đề xuất
Thêm 1 `GameEventBus` nhẹ (không phụ thuộc GetX Rx bắt buộc — có thể chỉ là `StreamController<GameEvent>` broadcast), định nghĩa `GameEvent` là sealed/union type mở rộng được. Consumer game code bắn 1 event duy nhất (`bus.emit(EntityDefeated(...))`), các service nghiệp vụ tự đăng ký subscriber cho loại event chúng quan tâm — thêm 1 service subscriber mới không cần sửa code bắn event.

## Acceptance criteria
- [x] `GameEventBus` typed, mở rộng được (thêm 1 loại `GameEvent` mới không cần sửa bus).
- [x] Ít nhất 2 service nghiệp vụ (ví dụ `EconomyWallet`, `AchievementService`) có ví dụ subscriber thật trong `example/` minh hoạ cùng 1 event bắn ra kích hoạt cả 2 độc lập.
- [x] Export trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.
- [x] Test unit cho bus (emit/subscribe/multiple subscriber, subscriber exception không làm crash bus/subscriber khác), widget/integration test cho demo trong `GameDemoScreen`.
- [x] Không bắt buộc mọi game dùng kit phải dùng bus này (optional, không breaking `RoyGame` hiện tại).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-88-typed-game-event-bus.md` này trước khi làm. Đọc toàn bộ `lib/presentation/game/roy_game.dart`, `example/lib/screens/game_demo_screen.dart`, và cách các service nghiệp vụ hiện có (`EconomyWallet`, `AchievementService`) expose API trước khi thiết kế bus. Implement bằng TDD. Cân nhắc kỹ (ponytail) — đây effort L, ưu tiên thiết kế tối giản (1 `StreamController` + sealed class) trước khi thêm bất kỳ cơ chế phức tạp hơn (priority, cancellation token...).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget/integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device Android thật (mở `GameDemoScreen`, trigger sự kiện demo, verify cả 2 service subscriber phản ứng đúng, quan sát được qua UI/log).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — gap hợp lý dựa trên kiến trúc đã biết của kit (nhiều service nghiệp vụ độc lập + 1 Flame integration point tối giản), nhưng đây là 1 đề xuất thiết kế mới (không phải bug/gap cụ thể đã verify bằng code), cần bàn kỹ về mức độ cần thiết trước khi implement full effort L. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `lib/core/game_event_bus.dart` — `GameEvent` (abstract marker
class, KHÔNG `sealed` — 1 hierarchy `sealed` phải nằm trọn trong package
này, trong khi 1 game thật cần tự định nghĩa event type của riêng nó bên
ngoài package, đúng đề xuất "Consumer game code bắn 1 event duy nhất"), và
`GameEventBus` (1 `StreamController<GameEvent>.broadcast()` + `subscribe<T>`
lọc theo type + bắt exception từ subscriber qua `onError` callback thay vì
để rethrow). Tối giản đúng ghi chú ponytail của task — không thêm priority,
cancellation token, hay bất kỳ cơ chế nào khác ngoài yêu cầu.

`lib/presentation/game/roy_game.dart`: `RoyGame` nhận thêm 1 param optional
`GameEventBus? eventBus` (mặc định `null` — 100% không breaking, mọi
`RoyGame()` hiện có tiếp tục hoạt động y hệt). `TappableCircle.onTapDown`
emit `CircleTappedEvent` (1 `GameEvent` cụ thể, đặt ngay trong file này —
đúng vai trò "starter template" của `RoyGame`, một game thật tự định nghĩa
event type của mình bên ngoài package) qua `game.eventBus?.emit(...)` —
no-op hoàn toàn nếu không truyền bus.

`example/lib/screens/game_demo_screen.dart`: tạo 1 `GameEventBus`, subscribe
`CircleTappedEvent` để gọi ĐỘC LẬP cả `EconomyWallet.earn(currency: 'gems')`
VÀ `AchievementService.incrementProgress` từ CÙNG 1 event — đúng yêu cầu
"2 service nghiệp vụ ... cùng 1 event bắn ra kích hoạt cả 2 độc lập". Thêm
badge "gems: N | tap: N/10" trên UI để quan sát trực tiếp qua screenshot/
device, không chỉ qua log.

**TDD**: 7 test unit `test/core/game_event_bus_test.dart` (subscribe lọc
đúng type, mở rộng thêm loại event mới không sửa bus, nhiều subscriber độc
lập, subscriber throw bị bắt qua `onError` không làm mất event ở subscriber
khác/bus vẫn sống tiếp, throw không có `onError` không rethrow, `emit()`
sau `dispose()` không throw). Xác nhận fail đúng lỗi biên dịch khi tạm xoá
file lib, khôi phục pass 7/7. 2 test mới trong
`test/presentation/game/roy_game_test.dart` (`RoyGame()` không truyền
`eventBus` vẫn hoạt động bình thường; tap emit đúng `CircleTappedEvent` khi
có truyền bus) — stash `roy_game.dart` xác nhận fail đúng lỗi biên dịch,
khôi phục pass 9/9 (cả 7 test cũ trong file). 2 test mới trong
`example/test/game_demo_screen_test.dart` (tap cập nhật cả gems VÀ tap
progress trên badge; nhiều tap liên tiếp cộng dồn đúng, không mất event) —
stash `game_demo_screen.dart` xác nhận fail đúng (2 test fail), khôi phục
pass 6/6.

**Device smoke test (bắt buộc theo task) — TECNO SPARK 20 Pro+ (Android 14,
`115333744A005844`)**: build+cài `flutter run --release`, mở Demo Flame,
tap circle. **Lần 1 phát hiện bug thật**: badge hiện `tap: 1/10` đúng nhưng
`gems: 0` — KHÔNG cập nhật. Root cause: subscriber gọi
`unawaited(_wallet.earn(...))` rồi `setState(() {})` ngay lập tức — trên
device thật (SharedPreferences ghi qua platform channel, không đồng bộ như
mock trong test), `earn()`'s `await storage.setString(...)` chưa kịp resolve
khi `setState()` rebuild UI, badge hiện balance CŨ. Widget test không bắt
được lỗi này vì mock `SharedPreferences` + `tester.pump(100ms)` đủ thời gian
cho microtask resolve trước khi build lại — đúng loại lỗi timing chỉ device
thật mới lộ ra. **Fix**: đổi subscriber thành `async`, `await
_wallet.earn(...)` TRƯỚC `setState()`. Rebuild + cài lại, tap 2 lần liên
tiếp: `gems: 1 | tap: 2/10` rồi `gems: 2 | tap: 3/10` — cả 2 số cùng cập
nhật đồng bộ mỗi tap, xác nhận fix đúng. Terminate + uninstall app sau khi
xong. (Widget test suite rerun sau fix vẫn 6/6 pass — hành vi cuối cùng
giống hệt, chỉ khác thời điểm rebuild UI.)

**Kết quả cuối**: `flutter analyze` sạch ở root và `example/`. `flutter
test --exclude-tags slow` root: 2122 test, 19 fail — khớp đúng baseline
golden-image macOS-only đã biết, không có fail mới. `example/`: 136/136
pass. `dart run tool/api_compatibility.dart check`: `additive` (thêm
`GameEventBus`/`GameEvent`/`CircleTappedEvent`) → `snapshot` → lại
`unchanged`.

**Điểm trừ 0.5**: thiết kế `GameEvent` là abstract class thường (không
`sealed`) đánh đổi type-safety khi pattern-match (Dart không thể cảnh báo
"thiếu case" như với `sealed`) để đổi lấy khả năng mở rộng ngoài package —
đúng đánh đổi cố ý theo yêu cầu, không phải thiếu sót, nhưng đáng ghi nhận
là 1 trade-off, không phải "hoàn hảo tuyệt đối".
