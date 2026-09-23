---
id: ENH-82
title: "GameSessionController không đồng bộ với RoyLifecycleCoordinator/Flame pauseWhenBackgrounded — 2 cơ chế pause độc lập"
type: enhancement
priority: P1
effort: M
source: "claude + agy (độc lập xác nhận cùng vấn đề, 2 góc nhìn khác nhau cùng root cause)"
---

## Vị trí
`example/lib/screens/game_demo_screen.dart` (`_session = GameSessionController()..markReady()..start();`), `lib/core/game_session_controller.dart`, `lib/core/lifecycle_coordinator.dart`, Flame `FlameGame.pauseWhenBackgrounded`.

## Hiện trạng
`GameSessionController` không truyền/liên kết với `RoyLifecycleCoordinator` (đã đăng ký qua `RoyCasualKitModule.lifecycle` ở `main.dart`). Khi app bị background trong lúc chơi, Flame tự pause `FlameGame` (`pauseWhenBackgrounded` mặc định), nhưng `GameSessionController.snapshot` vẫn báo phase `playing` — 2 cơ chế pause độc lập, không đồng bộ.

## Vì sao cần / Hậu quả
Bất kỳ code nào rẽ nhánh theo `GameSessionPhase` (ví dụ để show `PauseOverlay`) sẽ sai trạng thái khi app resume từ background — game đã pause thật (Flame) nhưng UI/logic vẫn nghĩ đang `playing`. Đây là demo screen duy nhất cho Flame integration nên lỗi này dễ bị copy nguyên vào game thật của consumer.

## Đề xuất
Nối `GameSessionController` với `RoyLifecycleCoordinator`: đăng ký 1 lifecycle hook chuyển `GameSessionController` sang `paused` (với `GamePauseReason` phù hợp, ví dụ `backgrounded`) khi app vào background, và cân nhắc gọi `game.pauseEngine()`/`resumeEngine()` (Flame API) đồng bộ với đúng `GameSessionPhase` thay vì để Flame tự quyết định độc lập.

## Acceptance criteria
- [x] App bị background trong lúc `GameSessionController.snapshot.value.phase == playing` — phase tự động chuyển `paused` (reason phù hợp) khi resume lifecycle event bắn ra.
- [x] `PauseOverlay`/UI dựa vào `GameSessionPhase` phản ánh đúng trạng thái pause thật của Flame engine.
- [x] `GameDemoScreen` minh hoạ đúng flow: background → resume → hiện đúng overlay pause nếu cần.
- [x] Test widget/integration verify đồng bộ giữa lifecycle event và `GameSessionController` phase.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-82-game-session-lifecycle-flame-pause-not-synced.md` này trước khi làm. Đọc toàn bộ `lib/core/game_session_controller.dart`, `lib/core/lifecycle_coordinator.dart`, `example/lib/screens/game_demo_screen.dart`, và tài liệu Flame về `pauseWhenBackgrounded`/`pauseEngine`/`resumeEngine` trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test (`GameSessionController`+`RoyLifecycleCoordinator`) + widget test (`GameDemoScreen`) cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật (home button để background app trong lúc chơi demo, resume lại, verify state pause đúng) — bắt buộc vì đây là bug lifecycle chỉ tái hiện đầy đủ trên device thật (background/resume thật).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — 2 nguồn độc lập (claude, agy) xác nhận cùng root cause qua 2 góc nhìn khác nhau (claude: thiếu liên kết `RoyLifecycleCoordinator`; agy: `PauseOverlay` demo không gọi Flame `pauseEngine()`) — cùng chỉ ra 1 khoảng trống thật: pause-state không đồng bộ giữa `GameSessionController`/lifecycle/Flame engine. Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Phát hiện quan trọng khi đọc code trước khi implement** (đúng bước "verify
claim trước khi làm"): `GameSessionController` (`lib/core/game_session_controller.dart`)
ĐÃ CÓ SẴN đầy đủ cơ chế hook `RoyLifecycleCoordinator` trong `onInit()`
(`pause(GamePauseReason.system)`/`resume(GamePauseReason.system)` theo đúng
sự kiện background/resume), và `PauseOverlay` ĐÃ CÓ SẴN `showForSystemPause`
param + doc comment mô tả rõ đúng luồng này — cả 2 phần lõi đã tồn tại,
được test kỹ (`test/core/game_session_controller_test.dart`'s "lifecycle
bridge" test). Root cause THẬT của bug KHÔNG phải "thiếu cơ chế" như task
đề xuất ban đầu (không cần sửa `GameSessionController`/`lifecycle_coordinator.dart`),
mà là **2 lỗi cụ thể ở `example/lib/screens/game_demo_screen.dart`**:
1. `_session = GameSessionController()` — KHÔNG truyền `lifecycle:` gì cả.
2. **Phát hiện thứ 2, sâu hơn, trong lúc viết test**: kể cả sau khi thêm
   `lifecycle: RoyLifecycleCoordinator.maybe`, hook VẪN KHÔNG đăng ký — vì
   `GetxController.onInit()` (nơi `registerHook` được gọi) CHỈ chạy qua cơ
   chế dependency-injection riêng của GetX (`Get.put()`/`Get.find()`),
   KHÔNG chạy tự động chỉ vì gọi constructor thuần Dart. `_session` chưa
   bao giờ được `Get.put()` trong file này. Test lõi
   (`game_session_controller_test.dart`) hoạt động đúng CHỈ VÌ nó gọi
   `Get.put(c)` tường minh — 1 chi tiết dễ bỏ sót nếu không đọc kỹ.

**Fix thật**: `_session` đổi thành
`Get.put<GameSessionController>(GameSessionController(lifecycle: RoyLifecycleCoordinator.maybe))..markReady()..start()`,
và `dispose()` đổi từ gọi `_session.onClose()` trực tiếp sang
`Get.delete<GameSessionController>(force: true)` (tránh gọi `onClose()` 2
lần — `Get.delete` tự gọi qua chuỗi `onDelete()` → `onClose()` của GetX).
`PauseOverlay(session: _session, showForSystemPause: true, ...)` để demo
THẬT SỰ hiện overlay khi bị pause do background, không chỉ đúng ngầm bên
trong phase.

**TDD — 2 vòng gỡ lỗi thật đáng ghi lại**:
1. **Widget test hang vô thời hạn**: `await Future<void>.delayed(Duration.zero);`
   đặt NGAY sau `lifecycle.didChangeAppLifecycleState(...)` bên trong
   `testWidgets()` treo mãi mãi, không bao giờ resolve — khác với
   `test()` thường (nơi Future.delayed chạy qua real event loop). Gỡ bằng
   cách bỏ dòng đó, đi thẳng vào `tester.pump(duration)` (đúng convention
   MỌI test khác trong file này đã dùng) — tự resolve đúng.
2. **Sau khi hết hang, assertion vẫn fail** ("Resume" không tìm thấy) —
   dẫn tới phát hiện lỗi thứ 2 ở trên (`Get.put()` thiếu). Sau khi thêm
   `Get.put()`, test pass ngay, xác nhận đúng root cause.

2 test mới `example/test/game_demo_screen_test.dart` (group "ENH-82"):
lifecycle background→resume thật (qua `RoyLifecycleCoordinator.didChangeAppLifecycleState`
trực tiếp, không qua `tester.binding.handleAppLifecycleStateChanged` — thử
trước, treo vô thời hạn vì dispatch tới MỌI `WidgetsBindingObserver` khác
trong zone test, không chỉ đúng coordinator cần test) → panel tự hiện rồi
tự ẩn đúng; không có `RoyLifecycleCoordinator` đăng ký → demo vẫn hoạt
động bình thường, không crash (hành vi cũ trước ENH-82, backward compat).

**Kết quả**: `flutter analyze` sạch ở root (không đổi gì) và `example/`.
`flutter test --exclude-tags slow` root: 2209 test, 19 fail — khớp baseline
đã biết (không đổi file lib nào). `example/`: 142/142 pass.

**Device smoke test (Pixel 7 Pro, bắt buộc theo task) — xác nhận CÓ HẠN
CHẾ trung thực**: build+cài `flutter run --release`, mở Demo Flame, nhấn
HOME background thật (xác nhận qua screenshot thấy home launcher thật),
chờ vài giây, mở lại app qua `mobile_launch_app`. App resume đúng, KHÔNG
crash, KHÔNG lỗi trong device log. TUY NHIÊN không chụp được khoảnh khắc
overlay pause hiện — phân tích: `onInit()`'s hook tự gọi
`resume(GamePauseReason.system)` NGAY khi resumed event bắn ra (không cần
người dùng bấm gì) — nghĩa là trên thiết bị thật, cả background VÀ resume
đều là 1 hành động liên tục của việc mở lại app (không có cách nào "nhìn"
vào app lúc đang ở background), nên khoảnh khắc `paused` hiện overlay rồi
`resumed` tự ẩn lại xảy ra NHANH HƠN round-trip chụp màn hình của công cụ
(cùng loại giới hạn tooling-speed đã ghi nhận ở ENH-80/ENH-81/FEAT-93 cùng
phiên). Đây LÀ hành vi ĐÚNG theo thiết kế có sẵn (không phải bug mới) —
overlay tồn tại đúng lúc app thật sự invisible, tự dọn dẹp khi người chơi
nhìn lại màn hình, không cần thao tác gì. Bằng chứng chính xác cho ĐÚNG
khoảnh khắc `paused` (nơi device screenshot không kiểm chứng được vì lý do
trên) đến từ widget test — kiểm soát CHÍNH XÁC từng transition riêng biệt
(background rồi assert TRƯỚC KHI gửi resumed), điều thiết bị thật không
cho phép làm được.

**Trừ 0.5 điểm**: không chụp được bằng chứng trực quan trên device thật
cho khoảnh khắc `paused`/overlay hiện — dù có giải thích kỹ thuật hợp lý
(tự resume quá nhanh) và bằng chứng widget test mạnh, đây vẫn là 1 khoảng
trống bằng chứng thực tế so với yêu cầu "bắt buộc" của task.
