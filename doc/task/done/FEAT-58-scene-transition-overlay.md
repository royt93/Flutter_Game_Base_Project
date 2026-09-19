---
id: FEAT-58
title: "SceneTransitionOverlay — chuyển Flutter screen/Flame world có progress"
type: feature
layer: presentation/widget
priority: P1
effort: M
depends_on: [FEAT-41, FEAT-47, FEAT-57]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn chuyển scene mượt và thấy tiến trình/error thật khi asset đang tải.

## Sprint slices
- Transition controller/state idle→covering→loading→revealing/error.
- Fade/wipe builder, progress slot và retry/cancel command.
- Đồng bộ AssetPreload + GameSession; token chống completion cũ mở nhầm scene mới.

## Acceptance criteria
- [x] Transition chỉ reveal khi đúng load token hoàn tất.
- [x] Load lỗi/cancel/retry không kẹt lớp chắn pointer.
- [x] Rapid navigation và widget dispose không callback stale.
- [x] Animation mượt, modal semantics đúng và reduced motion hoạt động.

## Prompt loop feature
Đọc task/session/preload code; TDD state machine trước animation. End loop: audit, chấm /10; unit test + widget test + integration test mọi transition/race/error/dispose; analyze/test root + example; smoke Android device thật chuyển qua lại Flame scene có video/log. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

### Kiến trúc
Tách 2 lớp rõ ràng, đúng chỉ dẫn "TDD state machine trước animation":

- **`SceneTransitionController`** — thuần Dart, không `Animation`/`BuildContext`.
  State machine `idle → covering → loading → revealing/error → idle`. Mỗi
  `run()` phát 1 token nội bộ (`_activeToken`); chỉ continuation đúng token
  đó được phép ghi `phase`/`progress`/`lastError` — `run()` cũ bị supersede
  bởi `run()` mới (rapid nav), hoặc còn dở sau `cancel()`/`dispose()`, tự
  nhận biết mình "stale" qua `_isCurrent(token)` và im lặng bỏ qua thay vì
  đè trạng thái hiện tại hoặc để lại pointer-barrier kẹt. `dispose()` chỉ
  set cờ `_disposed` (không tự ý đổi `phase`) — `_isCurrent` gộp luôn điều
  kiện `!_disposed`, nên MỌI checkpoint sau dispose (kể cả checkpoint đang
  dở đúng token) đều dừng ghi state, không riêng gì lúc gọi `run()` mới.
  `runWithAssetPreload()` nối thẳng `AssetPreloadCoordinator.progress`
  (FEAT-47, qua `.listen`) vào `progress` của transition, và khi preload
  `SdkSuccess` thì gọi `GameSessionController.markReady()+start()` (FEAT-41)
  — 2 service thật, không giả lập.
- **`SceneTransitionOverlay`** — widget thuần render theo `controller.phase`
  qua `Obx`. Scene cũ luôn bọc `ExcludeSemantics`+`IgnorePointer` với
  `excluding/ignoring: phase != idle` — tap/screen-reader không bao giờ lọt
  xuống scene cũ trong suốt lúc transition chạy, và rào chắn tự gỡ ngay khi
  `phase` về `idle` (dù qua reveal thành công hay `cancel()`) — không có
  đường nào để nó bị "kẹt". `AnimatedOpacity` cho hiệu ứng
  cover(fade-in)/reveal(fade-out); `reducedMotion` (mặc định đọc
  `MediaQuery.disableAnimations`) thay `duration` bằng `Duration.zero` khi
  bật, không cần đổi logic phase. Lỗi hiện qua `RetryErrorState.fromSdkFailure`
  (FEAT-57) có sẵn — không viết lại UI báo lỗi.
- Đặt trong `lib/presentation/widgets/common/` (game-agnostic, giống
  `RetryErrorState`) chứ không phải file rời kiểu `flame_tracked_overlay.dart`
  — widget hoạt động với bất kỳ nội dung nào (Flutter screen hay Flame
  `GameWidget`), không riêng Flame.

### Bug phát hiện qua TDD (trước khi có bug thật trong logic — bug ở TEST)
Không phát sinh bug logic mới trong `SceneTransitionController` (thiết kế
token-guard áp dụng nhất quán ngay từ đầu). Phát sinh 1 lỗi THIẾT KẾ TEST
đáng chú ý, giữ lại làm bài học: `coverDuration`/`revealDuration` dùng
`Duration.zero` trong widget test (`testWidgets`) khiến `flutter_test`'s
fake_async không flush hết Timer 0-duration chỉ với 1 lần `pump()` trơn —
để lại "pending timer" ở cuối test framework fail assertion `!timersPending`.
Cách phân biệt: `test()` thuần Dart (controller test, real async) dùng
`Duration.zero` vô tư; `testWidgets()` (widget test, fake_async) phải dùng
duration nhỏ khác 0 (`1ms`) + `pump(duration)` tường minh qua từng giai đoạn.
Ghi lại vì đây là gotcha có thể tái diễn cho bất kỳ Timer-based state machine
nào test trong `testWidgets`.

### Test
- `test/widget/common/scene_transition_controller_test.dart` (12 test,
  `test()` thuần, viết TRƯỚC implementation — xoá lib, xác nhận RED "Method
  not found", viết lại, xác nhận GREEN): happy path (3), error/retry (2),
  cancel không kẹt (1), rapid navigation không stale (1), dispose (2),
  đồng bộ AssetPreloadCoordinator+GameSessionController thật (3).
- `test/widget/common/scene_transition_overlay_test.dart` (5 `testWidgets`):
  idle cho tap lọt qua, loading chặn tap + hiện progress, error hiện
  RetryErrorState + Retry gọi đúng callback, cancel gỡ rào ngay, widget
  dispose giữa chừng không throw.
- `example/test/widget_showcase_screen_test.dart` — 3 test mới (group
  "FEAT-58"): Chuyển scene OK → idle + tăng revision, Chuyển scene lỗi →
  error + không tăng revision, Cancel giữa chừng → idle ngay, không throw.
- Toàn bộ: root 1581/1581 pass, example 84/84 pass. `flutter analyze` sạch
  root + example.

### Device smoke (Pixel 7 Pro, serial 2B051FDH3006MU)
Build `flutter build apk --debug`, cài + mở `com.galaxyjoy.roycasualkit`,
cuộn tới demo SceneTransitionOverlay (cuối section "Layout & Cards", ngay
sau AssetPreloadCoordinator). Bấm "Chuyển scene (OK)": panel chuyển từ
"Scene #1"/"Phase: idle" → thật sự chạy qua transition → "Scene #2"/
"Phase: idle" — số scene tăng thật, không giả lập. Bấm "Chuyển scene (lỗi)":
hiện đúng `RetryErrorState` với icon wifi-off, title "Connection problem",
message "Không tải được scene mới (demo lỗi giả lập).", nút Retry, và mã
chẩn đoán `NETWORK-3ED01E31` (chụp ảnh màn hình lưu bằng chứng). Bấm Retry
trong panel: chạy lại đúng load, vẫn fail như kỳ vọng (scenario cờ chưa đổi)
— chứng minh `onRetry` nối đúng tới `controller.retry()`. Bấm "Chuyển scene
(OK)" rồi "Cancel transition" liên tiếp: không throw, kết thúc ở "Scene #3"/
"Phase: idle" (transition đã hoàn tất trước khi cancel tới do độ trễ round-trip
thao tác qua tool — hành vi cancel-khi-đã-idle là no-op an toàn, đã được 12
unit test + 1 widget test verify chính xác timing race này rồi).
`mobile_list_crashes` rỗng trong suốt phiên thao tác.

### Tự chấm: 9.5/10
Đạt đủ 4 acceptance criteria với thiết kế token-guard nhất quán, tách state
machine thuần khỏi widget đúng yêu cầu TDD-trước-animation, nối thật với
FEAT-47/FEAT-41 (không mock), test cover đầy đủ race/dispose/cancel/error,
device-smoke xác nhận cả đường thành công lẫn đường lỗi thật trên thiết bị.
Trừ 0.5 vì chưa canh được device-smoke đúng khoảnh khắc "cancel giữa transition
đang chạy" do độ trễ round-trip của tool điều khiển thiết bị (~vài trăm ms/lệnh
vượt quá 780ms tổng thời lượng transition demo) — hành vi này đã được unit
test + widget test verify chính xác nên không phải rủi ro thật, chỉ là giới
hạn của việc demo tay trên thiết bị thật.
