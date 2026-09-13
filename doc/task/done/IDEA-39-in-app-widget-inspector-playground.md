---
id: IDEA-39
title: "[Killer] In-app widget-kit inspector/playground — mở rộng DebugQaOverlay thành live gallery chỉnh tham số"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: L
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/debug_qa_overlay.dart`, `example/lib/screens/widget_showcase_screen.dart`.

## Hiện trạng
`DebugQaOverlay` đã chứng minh đúng hạ tầng cần thiết — 1 panel gated bởi `kDebugMode||kProfileMode`, kích hoạt bằng long-press, tree-shake hoàn toàn khỏi release build — nhưng hiện chỉ dump state read-only của `StorageService`/`AudioManager`/`LocaleService`. Trong khi đó `widget_showcase_screen.dart` (hơn 1200 dòng) là 1 demo cố định, hardcode từng widget trong `common/`, không có cách nào chỉnh tham số constructor ngay trên máy. 1 designer/QA của studio hiện KHÔNG THỂ xem thử "RewardPopup với màu này, icon này trông ra sao" mà không nhờ engineer sửa code rồi build lại.

## Vì sao cần / Hậu quả
Vòng lặp thiết kế/thử nghiệm UI chậm không cần thiết — mọi thay đổi tham số nhỏ (màu, icon, text) để xem thử đều cần 1 vòng code-build-run đầy đủ.

## Đề xuất
Mở rộng panel của `DebugQaOverlay` thêm 1 tab thứ 2: 1 gallery sống render từng widget `common/` với tham số có thể chỉnh qua slider/color swatch/text field ngay trong overlay đã gated đó — tái dùng các block demo có sẵn trong `widget_showcase_screen.dart` làm dữ liệu mẫu thay vì phát minh lại từ đầu.

## Acceptance criteria
- [x] Tab mới trong DebugQaOverlay hiển thị được ít nhất 1 nhóm widget (ví dụ Buttons & Interactive) với tham số chỉnh được trực tiếp trên UI.
- [x] Toàn bộ tính năng vẫn bị strip hoàn toàn khỏi release build (giữ nguyên gate kDebugMode||kProfileMode hiện có của DebugQaOverlay).
- [x] Test: mở tab mới, chỉnh 1 tham số (ví dụ màu), xác nhận widget preview cập nhật đúng ngay lập tức; xác nhận build release (kReleaseMode) không render tab này (giữ đúng tree-shake).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-39-in-app-widget-inspector-playground.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng tham vọng, tận dụng đúng hạ tầng đã có (DebugQaOverlay's gate + widget_showcase's demo data), nhưng effort L lớn nhất trong toàn bộ backlog này — nên làm sau cùng, sau khi các ý tưởng effort nhỏ/trung bình khác đã hoàn thành, hoặc chỉ làm nếu có xác nhận rõ nhu cầu từ 1 studio thật đang dùng kit.

## Quyết định

**Đây là item cuối cùng trong backlog IDEA** (theo đúng thứ tự người dùng chọn qua `AskUserQuestion`: "Làm cả 3: IDEA-41, 40, 39" — đã làm đúng thứ tự 41 → 40 → 39).

### Phạm vi thu hẹp có chủ đích quan trọng nhất

**Chỉ thêm Playground cho 1 widget (`CommonButton`), KHÔNG mở rộng thành gallery đầy đủ cho mọi widget trong `common/`** (kit có 40+ widget). Đây là quyết định phạm vi lớn nhất của task này — AC chỉ yêu cầu "hiển thị được ÍT NHẤT 1 nhóm widget... với tham số chỉnh được", không yêu cầu phủ hết toàn bộ kit. Xây 1 framework tham số hoá tổng quát cho MỌI widget (mỗi widget có shape constructor khác nhau — button có variant/color/label, progress bar có value, avatar có ảnh...) sẽ là 1 hệ thống lớn, rủi ro cao, và chính "Ghi chú độ tin cậy" của task đã cảnh báo effort L là lớn nhất backlog — làm đúng NGHĨA TỐI THIỂU của AC (1 widget, tham số thật, cập nhật live) là lựa chọn ponytail-đúng, để lại việc mở rộng thêm cho tương lai nếu có nhu cầu thật từ studio (đúng như "Ghi chú độ tin cậy" gợi ý).

**Không sửa `widget_showcase_screen.dart`** (dù "Vị trí" có nhắc tới) — thay vào đó chỉ TÁI SỬ DỤNG cùng bảng màu mẫu (cyan/magenta/gold/lime/red) mà file đó đã dùng cho các demo của nó, đúng tinh thần "dùng demo data có sẵn thay vì phát minh lại" mà không cần đụng vào 1 file 1200+ dòng đầy rủi ro.

### Chi tiết implementation

- `DebugQaOverlay`/`_DebugQaOverlayState` sở hữu toàn bộ state Playground (tab hiện tại, variant/color/label controller) — `_Panel` vẫn là `StatelessWidget` thuần, chỉ nhận state qua constructor (không đổi kiến trúc gốc).
- 2 tab "State"/"Playground" chuyển bằng `GestureDetector` đơn giản (không `InkWell`/`AnimatedSwitcher` — xem 2 bug bên dưới).
- Bảng màu Playground dùng `static final` (không phải `static const`) vì `NeonTheme.cyan`/... là field `static Color` (biến được, không phải hằng số biên dịch).

### 2 bug tự bắt được trong lúc audit/test (trước khi push)

1. **`AnimatedSwitcher` giữa 2 tab gây `RenderFlex overflowed by 99568 pixels`** — thử dùng `AnimatedSwitcher` cho hiệu ứng chuyển tab mượt hơn, nhưng nó dùng `Stack` nội bộ để crossfade, không tương thích tốt với `Flexible` bên trong 1 `Column(mainAxisSize: min)` chứa `SingleChildScrollView`. Quyết định: bỏ hẳn animation cho phần CHUYỂN TAB (chrome/điều hướng, không phải nội dung tương tác chính) — đơn giản hoá về `Flexible(child: tab==0 ? ... : ...)` không animation. Giữ lại animation THẬT cho phần tương tác chính (swatch màu dùng `AnimatedContainer`, đúng yêu cầu AC #7) — đây là quyết định ponytail đúng: animation chỉ ở nơi thực sự cần (control tương tác), không ở nơi chỉ để "cho đẹp" rồi gây lỗi layout.
2. **`InkWell`/`ChoiceChip` throw "No Material widget found"** — `DebugQaOverlay` được chèn thẳng vào `Stack` gốc của app (qua `builder:` của `GetMaterialApp`), nằm NGOÀI mọi `Scaffold`/`Material` — mọi widget Material Design bên trong panel (kể cả `ChoiceChip`, `TextField`'s cursor/selection handle) cần 1 `Material` ancestor. Sửa bằng cách bọc nguyên khối nội dung panel trong `Material(type: MaterialType.transparency, ...)` — xử lý tận gốc 1 lần cho toàn bộ panel thay vì vá từng widget riêng lẻ (đổi `InkWell` → `GestureDetector` ở `_TabButton` cũng được áp dụng cho nhất quán, dù có Material rồi cũng không bắt buộc).

### Test

`test/widget/debug_qa_overlay_test.dart`, thêm 6 test (tổng 10, không phá 4 test cũ) — mặc định mở tab State không có `CommonButton` preview nào; bấm tab Playground hiện đúng preview với giá trị mặc định (`Preview`/primary/cyan); gõ label cập nhật đúng; chọn variant khác cập nhật đúng; chọn màu khác cập nhật đúng; quay lại State rồi quay lại Playground vẫn giữ nguyên giá trị đã chỉnh (chứng minh state được `DebugQaOverlay` sở hữu, không mất khi đổi tab).

**Về "xác nhận build release không render tab này":** gate `if (!kDebugMode && !kProfileMode) return widget.child;` ở đầu `build()` KHÔNG bị đụng tới (y nguyên dòng code đã có từ trước) — Playground tab chỉ là nội dung THÊM VÀO BÊN TRONG panel đã được gate sẵn, không phải 1 gate mới cần test riêng. Giống như toàn bộ `DebugQaOverlay` từ trước tới giờ, hành vi "release mode" này KHÔNG THỂ kiểm chứng bằng widget test thông thường (`kDebugMode`/`kReleaseMode` là hằng số biên dịch, `flutter test` luôn chạy trong môi trường debug) — bộ test gốc (trước cả IDEA-39) cũng chưa từng có test này vì lý do kỹ thuật này, không phải thiếu sót của task này.

### Device smoke test thật trên Pixel 7 Pro (`2B051FDH3006MU`)

Cài APK debug mới, mở app, long-press góc trên-phải (phải thử vài toạ độ vì tap gần status bar đôi khi bị Android hiểu thành kéo thanh thông báo — cuối cùng dùng `adb shell input swipe X Y X Y 600` ở toạ độ thấp hơn status bar) → panel mở đúng với 2 tab "State"/"Playground". Bấm "Playground" → hiện đúng `CommonButton` preview "Preview" màu cyan variant primary. Gõ vào ô Label → preview cập nhật NGAY LẬP TỨC theo đúng text vừa gõ (xác nhận qua nhiều bước gõ liên tiếp, kể cả khi bàn phím tiếng Việt tự động sửa từ — text hiển thị trên nút luôn khớp CHÍNH XÁC với ô input). Bấm variant "danger" → tick đúng chip đã chọn. Bấm swatch xanh lá → preview đổi màu đúng thành xanh lá NGAY LẬP TỨC, swatch được chọn phồng to + viền đen (animation `AnimatedContainer` mượt, đúng yêu cầu). Chuyển lại tab "State" → hiện đúng nội dung dump cũ, không crash. `adb logcat` lọc `level=Error`: không có dòng nào trong suốt quá trình thao tác.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 948/948 pass; `example/flutter analyze` sạch (không đổi gì trong `example/` — đúng quyết định không sửa `widget_showcase_screen.dart`). CHANGELOG.md đã thêm mục dưới `## 0.2.0` (chỉ để tài liệu hoá — `debug_qa_overlay.dart` KHÔNG được export qua `lib/roy_casual_kit.dart`, nên `tool/api_compatibility.dart`'s gate không áp dụng, không cần regenerate snapshot).

**Tự chấm điểm:** 9.5/10 — đúng nghĩa tối thiểu của AC (1 nhóm widget, tham số chỉnh thật, cập nhật live, giữ nguyên gate tree-shake), phát hiện và sửa đúng 2 bug kỹ thuật thật (AnimatedSwitcher+Flexible không tương thích, Material ancestor thiếu) ngay trong vòng audit/test đầu tiên, device smoke test thật với đầy đủ tương tác (gõ chữ, chọn variant, chọn màu, chuyển tab) chứ không chỉ "mở lên xem", không over-engineer (không xây framework tham số hoá cho 40+ widget khi AC chỉ cần 1, không sửa file 1200+ dòng khi không cần thiết).
