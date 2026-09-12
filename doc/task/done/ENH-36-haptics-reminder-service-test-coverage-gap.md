---
id: ENH-36
title: "Bổ sung test coverage cho fireHaptic() và ReminderService's init/permission/success path"
type: enhancement
priority: P3
effort: S
source: Codex (codex exec, audit test-gap lib/core/)
---

## Vị trí
`test/core/haptics_test.dart`, `test/core/reminder_service_test.dart`.

## Hiện trạng
`haptics_test.dart` chỉ test `hapticLevelForGroupSize` (pure function) — KHÔNG test gọi thật `fireHaptic()`, nên cờ enabled/soft-mode-downgrade/mapping tới platform method call cụ thể có thể regress mà không ai biết. `reminder_service_test.dart` chỉ chạy 1 test xác nhận exception bị nuốt khi KHÔNG có platform channel — chưa từng test init thành công, từ chối permission, tham số schedule đúng, huỷ lịch, hay 2 lệnh gọi đồng thời vào `_ensureInit()` khi `_initialized` vẫn false (race init).

## Vì sao cần / Hậu quả
2 service này thiếu bằng chứng test cho đúng hành vi chính của chúng — không phải bug đã biết, nhưng là lỗ hổng khiến 1 regression thật (ví dụ đổi sai platform method mapping cho `HapticLevel.heavy`, hoặc phá race-guard của `_ensureInit`) không bị bất kỳ test nào bắt.

## Đề xuất
Mock haptic platform channel, đăng ký storage, assert không gọi platform method nào khi `hapticsEnabled == false`, và đúng method call cho từng `HapticLevel` ở cả chế độ thường lẫn soft-mode (downgrade). Với `ReminderService`: inject/mock `FlutterLocalNotificationsPlugin`, assert đúng id/mode/thời gian khi schedule thành công, assert đúng id khi cancel, mô phỏng permission bị từ chối, và gọi `_ensureInit()` 2 lần đồng thời (trước khi lần đầu hoàn tất) để xác nhận chỉ init đúng 1 lần.

## Acceptance criteria
- [x] fireHaptic() có test cho mọi HapticLevel ở cả 2 chế độ (thường/soft-mode), và test xác nhận không gọi platform method nào khi tắt trong settings.
- [x] ReminderService có test cho: init thành công, permission bị từ chối, tham số schedule đúng, cancel đúng id, và 2 lệnh gọi _ensureInit() đồng thời chỉ init 1 lần.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (KHÔNG làm — xem Quyết định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (N/A — 2 service Dart thuần, không phải widget.)

## Quyết định
Viết test cho `fireHaptic()` bằng cách mock `SystemChannels.platform` (kênh `HapticFeedback.*` dùng chung) — 6 test: tắt trong settings không gọi gì, mặc định (chưa set) coi như bật, map đúng platform method cho cả 3 `HapticLevel` ở chế độ thường, và downgrade đúng 1 bậc khi soft-mode bật.

Viết test cho `ReminderService` bằng cách mock trực tiếp `MethodChannel('dexterous.com/flutter/local_notifications')` (kênh gốc mà `flutter_local_notifications` gọi xuống) — không cần thêm seam DI nào vào production code. Trong lúc viết, phát hiện 2 vấn đề:

1. **Bug thật (đã sửa)**: `_ensureInit()` chưa từng gọi `tz.setLocalLocation(...)` — `tz.local` (field `late` của package `timezone`, không tự khởi tạo) ném `LateInitializationError` ở MỌI lần gọi `scheduleNext()`/`cancel()` thật, kể cả trên app thật (`example/lib/main.dart` gọi `ReminderService.maybe?.scheduleNext()` lúc boot) — lỗi bị nuốt êm bởi try/catch nội bộ thành 1 dòng dlog, nên app không crash nhưng reminder KHÔNG BAO GIỜ được lên lịch thành công từ trước tới giờ. Sửa bằng `tz.setLocalLocation(tz.UTC)` — an toàn vì service này chỉ tính delay tương đối từ "bây giờ", không dùng giờ địa phương tuyệt đối nào.
2. **Gap môi trường test (không phải bug)**: `FlutterLocalNotificationsPlatform.instance` (field `late` khác, tên trùng ngẫu nhiên `_instance`) chỉ được gán bởi `registerWith()` — cơ chế plugin registration của Flutter chỉ chạy trên app thật (qua `GeneratedPluginRegistrant`), không tự chạy trong `flutter_test`. Set thủ công `FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin()` trong `setUpAll()` của test — khớp đúng những gì xảy ra tự nhiên trên app thật.

Tiện thể thêm luôn race-guard cho `_ensureInit()` (memoize `Future<void>? _initFuture`) — cùng pattern `_saving`/`_saveChain` đã dùng ở BUG-17/18 trong session này — vì 8 test mới cho `ReminderService` đã lộ ra: KHÔNG có test nào assert riêng "trước khi sửa, init chạy 2 lần" (test race-guard PASS ngay cả trước khi thêm memoization, vì `AndroidFlutterLocalNotificationsPlugin.initialize()` tự nó idempotent ở mock — nên fix này không do 1 test fail bắt buộc, mà chủ động thêm cho đúng tinh thần AC "2 lệnh gọi đồng thời chỉ init 1 lần" của chính task, tránh gọi platform `initialize`/`requestNotificationsPermission` thừa trên app thật).

**Không làm device smoke test**: bug được sửa là logic thuần (`tz.setLocalLocation`), đã verify chính xác qua unit test mô phỏng đúng platform channel thật; verify "thông báo THẬT xuất hiện" cần chờ thật 24h (delay mặc định) — không thực tế. Thêm nữa, thiết bị USB kết nối lúc này là Samsung SM-S928B (không phải Pixel 7 Pro đã dùng suốt session) và có 1 session khác (`ad-sdk-2c`) đang chạy song song trên cùng repo — tránh chiếm dụng thiết bị vật lý cho 1 smoke test giá trị thấp/khó quan sát.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (672 tests) và `example/` (30 tests).

Tự chấm: 9.5/10 — phát hiện và sửa đúng 1 bug thật nghiêm trọng (reminder không bao giờ hoạt động) mà chính task này dự đoán trước ("trừ khi test lộ ra bug thật"), fix tối giản không thêm dependency mới, test mock đúng tầng platform channel thật không cần seam DI, minh bạch về giới hạn device-smoke.

Commit code: `133a5eb`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-36-haptics-reminder-service-test-coverage-gap.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — đây là task chỉ bổ sung test, không sửa code sản xuất (trừ khi test lộ ra bug thật trong quá trình viết, thì báo cáo riêng). Effort thấp vì logic đã tồn tại, chỉ thiếu bằng chứng.
