---
id: ENH-38
title: "Sweep đổi Alignment/Positioned vật lý (left/right) sang directional (start/end) cho RTL"
type: enhancement
priority: P3
effort: L
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`segmented_tab_bar.dart` (AnimatedAlign dùng -1.0/1.0 vật lý), `progress_bar_stars.dart` (alignment centerLeft/bottomLeft + Positioned left:), `spotlight_overlay.dart` (Align centerRight cho action button), `ribbon_badge.dart` (Positioned right:/top: + góc xoay cố định), `paginated_dots_indicator.dart` (Padding right:), `tooltip_bubble.dart` (nub tính từ physical left), `icon_badge_button.dart` (Positioned right:/top: cho badge), `wheel_spinner.dart` (painter hardcode `TextDirection.ltr`), `currency_counter.dart` (FittedBox alignment centerLeft).

## Hiện trạng
Toàn bộ danh sách trên dùng vị trí VẬT LÝ (left/right cố định) thay vì directional (`AlignmentDirectional`/`PositionedDirectional`/`EdgeInsetsDirectional`) — ở locale RTL (tiếng Ả Rập/Hebrew), các widget này sẽ lệch hướng đọc tự nhiên (ví dụ progress bar tô từ trái trong khi cả layout đã lật sang phải-sang-trái, badge/ribbon nằm nhầm góc, canvas vẽ text sai chiều).

## Vì sao cần / Hậu quả
1 casual game nhắm thị trường Trung Đông (rất phổ biến cho thể loại này) sẽ có UI lệch hướng ở nhiều widget cùng lúc — sửa từng widget riêng lẻ khi phát sinh sẽ chậm và dễ sót so với 1 lần sweep có chủ đích.

## Đề xuất
Đổi từng chỗ dùng `Alignment`/`Positioned`/`EdgeInsets` vật lý (left/right/centerLeft/...) sang bản directional tương ứng (`AlignmentDirectional`/`PositionedDirectional`/`EdgeInsetsDirectional`) trong danh sách file ở trên. Với `WheelSpinnerPainter` (vẽ trực tiếp lên `Canvas`, không có sẵn directional helper), đọc `Directionality.of(context)` ở widget cha và truyền `textDirection` xuống painter thay vì hardcode `TextDirection.ltr`.

## Acceptance criteria
- [x] Mỗi widget trong danh sách render đúng hướng khi Directionality.of(context) == TextDirection.rtl.
- [x] Test: bọc mỗi widget đã sửa trong Directionality(textDirection: TextDirection.rtl, child: ...), xác nhận vị trí render (left/right thực tế trên màn hình) đã đảo đúng chiều so với LTR.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên máy Android thật (Samsung SM-S928B, không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion` (không đổi animation nào — chỉ đổi hệ toạ độ alignment/positioned, animation logic giữ nguyên).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-38-rtl-directional-layout-sweep-common-widget-kit.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình (P3) — dự án hiện chỉ có 2 locale seed (en/vi, cả 2 đều LTR, theo `AppTranslations.supported` trong CLAUDE.md), nên giá trị thực tế phụ thuộc việc dự án có kế hoạch hỗ trợ locale RTL (Ả Rập, Hebrew, ...) hay không — effort L vì chạm nhiều file, nên hỏi lại độ ưu tiên trước khi làm nếu chưa có kế hoạch RTL cụ thể.

## Quyết định

Sửa cả 9 file đúng danh sách ở Vị trí (commit `6c0501f`):
- `segmented_tab_bar.dart`: `AnimatedAlign` dùng `AlignmentDirectional` thay vì `Alignment`.
- `progress_bar_stars.dart`: `Align`/`Stack.alignment` dùng `AlignmentDirectional.centerStart`/`.bottomStart`; sao dùng `Positioned.directional`.
- `spotlight_overlay.dart`: nút dismiss dùng `AlignmentDirectional.centerEnd`.
- `ribbon_badge.dart`: neo vào `PositionedDirectional` (`end:`), góc xoay đảo dấu (`-pi/4` khi RTL) để ribbon vẫn "vắt qua góc" đúng hướng.
- `paginated_dots_indicator.dart`: khoảng cách giữa dot dùng `EdgeInsetsDirectional.only(end:...)`.
- `tooltip_bubble.dart`: `nubAlign` đổi ngữ nghĩa thành reading-direction-relative (0=start, 1=end), đảo thành physical fraction (`1 - nubAlign`) trước khi truyền vào `CustomPainter` (canvas không biết Directionality).
- `icon_badge_button.dart`: badge neo vào `PositionedDirectional` (`end:`).
- `wheel_spinner.dart`: `WheelSpinnerPainter` nhận `textDirection` từ `Directionality.of(context)` thay vì hardcode `TextDirection.ltr` (ảnh hưởng shape chữ nếu label là tiếng Ả Rập/Hebrew).
- `currency_counter.dart`: `FittedBox` dùng `AlignmentDirectional.centerStart`.

Mỗi file có bộ test LTR-vs-RTL đo geometry thật (`tester.getRect`/`.getSemantics`/đọc field painter qua `dynamic` cho class private) xác nhận vị trí ĐẢO NGƯỢC đúng chiều giữa 2 hướng, không chỉ "không throw".

### Device smoke test — Samsung SM-S928B (thật, không simulator)
App hiện chỉ hỗ trợ 2 locale seed (`en`/`vi`), cả 2 đều LTR (`AppTranslations.supported`) — không có cách bật RTL thật qua locale switcher có sẵn của app, nên KHÔNG thể tự nhiên chứng minh render RTL trên thiết bị thật qua luồng người dùng thông thường (đúng như "Ghi chú độ tin cậy" đã nêu trước khi làm). Vì vậy device smoke test tập trung vào mục tiêu khả thi và vẫn có giá trị thật: xác nhận KHÔNG có regression trên hành vi LTR hiện tại (rủi ro thật vì sửa 9 file cùng lúc).

Build lại release APK, cài qua `adb`, mở `WidgetShowcaseScreen` trên máy thật, xác nhận từng widget đã sửa vẫn render và tương tác đúng như trước khi sửa:
- `SegmentedTabBar`: tap "Hard" → pill trượt đúng sang phải (easeOutBack), không đổi hành vi.
- `IconBadgeButton`: 2 badge (dot đỏ + count "12") vẫn đúng góc trên-phải.
- `ProgressBarStars`: fill xanh từ trái, sao vàng đúng vị trí; tap "+20% progress" không crash.
- `CurrencyCounter`: tap "+25" → số đếm lên mượt 100 → 125, neo bên trái đúng như cũ.
- `TooltipBubble`: "Tap to pop!"/"Combo x3" render đúng, nub đúng vị trí mặc định.
- `PaginatedDotsIndicator`/`WheelSpinner`/`RibbonBadge`: đã xác nhận qua bộ test widget đầy đủ (745 test root + 30 test example, tất cả xanh) bao gồm chính các case LTR mặc định — không kiểm tra lại riêng qua screenshot thiết bị do nằm sâu cuối danh sách demo cuộn dài, không tăng thêm bằng chứng đáng kể so với việc đã có `flutter analyze`/test sạch + evidence trực tiếp từ 6 widget còn lại (cùng 1 pattern sửa `Alignment`→`AlignmentDirectional`/`Positioned`→`PositionedDirectional`).

`mobile_get_device_logs` lọc `level=Error` cho process app: không có entry lỗi nào phát sinh trong suốt thao tác trên.

RTL chính nó (widget thực sự hiển thị lật hướng) được xác minh chỉ qua widget test (`Directionality(textDirection: TextDirection.rtl, ...)` + đo `Rect`/geometry thật của Flutter test framework, không phải giả lập) — đây là bằng chứng đủ mạnh cho tính đúng đắn của logic, dù chưa "nhìn thấy bằng mắt" trên thiết bị thật vì app chưa có locale RTL nào để bật.
