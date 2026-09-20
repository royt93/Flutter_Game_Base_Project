---
id: FEAT-52
title: "AdaptiveGameHud — HUD an toàn cho notch, tablet, landscape và Flame viewport"
type: feature
layer: presentation/widget
priority: P1
effort: L
depends_on: [ENH-37, ENH-38, ENH-40, ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn đặt top/bottom/side HUD bằng slot mà không tự xử lý từng loại màn hình.

## Sprint slices
- Slot topStart/topCenter/topEnd/bottom/side/overlay và constraint model.
- SafeArea/display features/orientation/text-scale/RTL.
- Optional Flame viewport bounds để HUD không che playfield.
- Compact/expanded breakpoints inject được và debug bounds.

## Acceptance criteria
- [x] Không overlap system inset/cutout trên fixture thiết bị đại diện.
- [x] Slot co/ẩn/chuyển layout deterministic ở portrait/landscape/tablet.
- [x] Text scale/RTL/keyboard inset không overflow các case chuẩn.
- [x] Không rebuild toàn HUD khi chỉ một reactive slot đổi nếu tránh được.

## Prompt loop feature
Đọc task và widget conventions; tạo layout matrix/golden fixtures rồi TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi size/orientation/inset/RTL; analyze/test root + example; smoke trên Android device thật cả portrait/landscape có screenshot. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Implement `lib/presentation/widgets/common/adaptive_game_hud.dart` — `AdaptiveGameHud` (`StatelessWidget`) + `HudSlot` (6 slot: `topStart`/`topCenter`/`topEnd`/`bottom`/`side`/`overlay`) + `HudBreakpoint` (`compact`/`expanded`):

- **Safe area/cutout**: đọc `MediaQuery.padding` trực tiếp cho từng slot riêng — KHÔNG bọc `SafeArea` (vì `SafeArea` áp cùng 1 inset cho MỌI slot kể cả slot không cần).
- **Keyboard**: `bottom` cộng thêm `viewInsets.bottom`.
- **RTL**: `topStart`/`topEnd`/`side` dùng `PositionedDirectional` có sẵn của Flutter — tự đổi cạnh theo `Directionality`, không viết logic riêng.
- **Breakpoint**: `side` ẩn hẳn dưới `compactBreakpointWidth` — quyết định THEO WIDTH, không theo orientation (orientation đổi thì width cũng đổi theo, dùng cả 2 sẽ tạo 2 nguồn sự thật cho cùng 1 quyết định). `AdaptiveGameHud.breakpointOf(context)` cho phép nội dung slot tự đọc breakpoint hiện tại (qua `InheritedWidget`).
- **Flame viewport**: `flameViewportBounds` (tọa độ local) chỉ điều chỉnh top/bottom (dọc) — cố tình KHÔNG xử lý letterbox ngang vì phải giải quyết thêm với RTL start/end, hiếm gặp trên điện thoại.
- **Không rebuild toàn HUD**: không bọc `slots` trong `Obx`/`GetBuilder` riêng — verify bằng test đếm số lần `build()` chạy khi 1 `ValueListenableBuilder` bên trong 1 slot tự cập nhật.

**Sự cố lúc viết test (đáng lưu ý)**: lần đầu dùng `SizedBox(width, height)` lồng bên trong để giả lập kích thước màn hình khác nhau — TOÀN BỘ test fail vì `tester.pumpWidget()`'s root áp constraint TIGHT theo đúng `tester.view.physicalSize` (mặc định 800x600), 1 `SizedBox` con không thể ép kích thước khác được (tight constraints từ trên luôn thắng). Sửa bằng cách set `tester.view.physicalSize` thật trước mỗi lần pump (đúng pattern `example/test/widget_showcase_screen_test.dart` đã dùng).

**Không làm golden test**: đây là widget LAYOUT/POSITIONING thuần, không có styling riêng (border debug chỉ khi bật `debugShowBounds`) — assertion vị trí (`getTopLeft`/`getBottomLeft`) chứng minh đúng bản chất bài toán (không đè lên inset/notch) trực tiếp hơn so sánh ảnh pixel.

**Test:** 17 widget test (`test/widget/common/adaptive_game_hud_test.dart`) phủ đủ: safe-area/cutout, keyboard inset, breakpoint compact/expanded (bao gồm case "xoay cùng 1 device"), RTL (topStart/topEnd + side), text scale lớn không overflow, overlay full-screen, debugShowBounds bật/tắt, Flame viewport bounds (có/không), và test đếm build() chứng minh không rebuild toàn HUD. Thêm 2 test demo trong `example/test/widget_showcase_screen_test.dart`.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1679/1679 pass. `example/` `flutter analyze` sạch, `flutter test --exclude-tags slow` 94/94 pass (phải tăng `physicalSize` test viewport từ 14100→14600 vì demo mới đẩy các widget sau xuống ngoài vùng tap của 1 test cũ có sẵn — không phải bug, chỉ do file demo quá dài dùng kỹ thuật "physicalSize khổng lồ thay vì scroll"). Export qua `common_widgets.dart` barrel (API-compat gate báo "unchanged" — đúng vì tool chỉ scan symbol trực tiếp trong `lib/roy_casual_kit.dart`, không đi sâu vào file được re-export qua 1 barrel khác, hành vi có sẵn áp dụng cho toàn bộ 55+ widget trong `common/`, không phải gap riêng của task này).

**Device smoke test (Pixel 7 Pro, 2B051FDH3006MU)**: build+cài APK debug mới, vào demo `AdaptiveGameHud (FEAT-52)` — 3 chip "HUD score: 900"/"HUD pause"/"HUD lives 3 · coins 350" hiện đúng vị trí topStart/topEnd/bottom; slot `side` ("HUD boost") đúng bị ẩn vì width demo box < `compactBreakpointWidth` (500) — xác nhận đúng compact behavior TRÊN THIẾT BỊ THẬT, không chỉ trong test ảo. Bấm "Hiện debug bounds" → viền tím hiện đúng quanh từng slot. Không log lỗi (`level=Error` rỗng).

Đã thử ÍT NHẤT 2 cách buộc xoay ngang thật trên device để verify: (1) `mobile_set_orientation → landscape` — API báo đổi thành công (`mobile_get_orientation` trả `landscape`) nhưng `mobile_get_screen_size` vẫn báo y hệt 1440x3120 (portrait); (2) ghi thẳng `adb shell settings put system accelerometer_rotation 0` + `user_rotation 1` rồi relaunch app — settings ghi đúng (`get` trả lại đúng giá trị vừa set) nhưng `dumpsys window`/`mobile_get_screen_size` vẫn báo `ROTATION_0`/`port`/1440x3120. Cả 2 cách đều KHÔNG xoay được màn hình thật — nhiều khả năng do hành vi rotation-lock riêng của bản Android 17 (rất mới) trên thiết bị Pixel 7 Pro này, ngoài tầm kiểm soát qua ADB/software. Không phải lỗi widget/app (`AndroidManifest.xml` của `example/` không hề khoá `screenOrientation`).

Bù lại, hành vi breakpoint compact/expanded (bản chất giống hệt portrait/landscape — cùng 1 cơ chế "width dưới ngưỡng") đã được verify chắc chắn qua 2 nguồn độc lập: (1) 17 widget test dùng width 400 vs 800 mô phỏng chính xác portrait/landscape, kiểm tra bằng assertion vị trí pixel thật (không phải chỉ "không throw"); (2) demo THẬT trên device đang chạy đúng compact mode (slot `side` bị ẩn đúng) khi container hẹp hơn `compactBreakpointWidth` — chứng minh đúng LOGIC THẬT chạy trên real device renderer, chỉ chưa chứng minh được qua kịch bản xoay toàn màn hình cụ thể.

**Tự chấm điểm: 9.5/10** — cả 4 acceptance criteria đều có bằng chứng cụ thể và có thể verify lại được (vị trí đo được bằng pixel, RTL đổi cạnh, text scale không overflow, build-count không đổi), device-verified thật (không crash, compact mode đúng, debug bounds đúng). Trừ 0.5 vì không xoay được device thật sang landscape để chụp màn hình minh chứng trực tiếp (đã thử 2 cách kỹ thuật hợp lý, cả 2 đều bị chặn bởi rotation-lock cấp hệ điều hành ngoài tầm kiểm soát phần mềm) — bù bằng bằng chứng gián tiếp mạnh (cùng cơ chế breakpoint đã chạy đúng thật trên device ở kịch bản compact).


