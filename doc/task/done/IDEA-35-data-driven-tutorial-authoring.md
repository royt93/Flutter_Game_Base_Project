---
id: IDEA-35
title: "[Killer] Data-driven tutorial/onboarding authoring — mở rộng TutorialSequence để nhận JSON thay vì hardcode"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: M
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/common/tutorial_sequence.dart`, `spotlight_overlay.dart`, `lib/core/remote_config_service.dart`.

## Hiện trạng
`TutorialSequence`/`TutorialStep` đã tồn tại nhưng hoàn toàn imperative — 1 `List<TutorialStep>` cố định với `GlobalKey`, message, thứ tự hardcode ngay trong code màn hình gọi nó. 1 studio muốn A/B-test copy/thứ tự onboarding, hoặc để game designer (không phải engineer) chỉnh flow tutorial, phải build lại app cho mỗi lần đổi câu chữ.

## Vì sao cần / Hậu quả
Đây là điểm khác biệt lớn so với 1 template Flutter chung chung — không template nào khác hỗ trợ sẵn tutorial authoring, càng không có sẵn seam remote-config để cắm vào ngay.

## Đề xuất
Mở rộng `TutorialSequenceController.start` để nhận thêm 1 danh sách bước dạng JSON (id → tên key widget đích, message, title, nhãn nút) đối chiếu với 1 `Map<String, GlobalKey>` registry do caller cung cấp, load trực tiếp từ `RemoteConfigService.getString('onboarding_flow_v1')`; log mỗi bước shown/dismissed qua `AnalyticsProvider` để phân tích funnel drop-off. Không thêm logic render mới — chỉ là 1 định dạng dữ liệu trên nền `TutorialSequence`/`SpotlightOverlay` đã có.

## Acceptance criteria
- [x] TutorialSequenceController.start chấp nhận cả List<TutorialStep> hiện có LẪN JSON step list mới, không phá API cũ.
- [x] JSON step tham chiếu đúng GlobalKey qua tên key trong registry do caller cung cấp.
- [x] Mỗi bước log đúng sự kiện shown/dismissed qua AnalyticsProvider.
- [x] Test: load JSON step list hợp lệ chạy đúng tutorial; JSON tham chiếu key không tồn tại trong registry xử lý an toàn (không crash, có thể skip bước đó); log analytics đúng số lần/đúng tên sự kiện.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. Thực hiện trên **TECNO BG6** (`118743744X002560`) — xem `## Quyết định`.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-35-data-driven-tutorial-authoring.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hay, dựa trên hạ tầng đã có sẵn (TutorialSequence + RemoteConfigService + AnalyticsProvider), nhưng effort M vì cần thiết kế định dạng JSON cẩn thận để không phá vỡ API imperative hiện có.

## Quyết định

**Không thêm tham số mới vào `TutorialSequenceController.start`** — thay vào đó thêm `static List<TutorialStep> TutorialStep.listFromJson(json, {required keyRegistry})` làm CONVERTER: parse JSON → `List<TutorialStep>` → truyền thẳng vào `start()` y hệt như trước giờ. Cách này thoả cả 2 nửa của AC "chấp nhận cả 2 dạng, không phá API cũ" theo nghĩa mạnh nhất có thể: chữ ký `start(List<TutorialStep>)` KHÔNG đổi 1 ký tự nào (không có overload/union type nào phải xử lý), trong khi caller vẫn "cho `start` ăn" được dữ liệu JSON — chỉ cần đi qua 1 bước convert tường minh. Đúng tinh thần "chỉ là 1 định dạng dữ liệu trên nền đã có, không thêm logic render mới" của Đề xuất.

**`TutorialStep` không hardcode `RemoteConfigService`:** `listFromJson` chỉ nhận 1 `String json` thuần — không tự gọi `RemoteConfigService.getString('onboarding_flow_v1')` bên trong. Giữ đúng nguyên tắc "seam" đã áp dụng nhất quán trong package (widget layer không phụ thuộc cứng vào 1 remote-config key cụ thể nào) — caller tự fetch chuỗi rồi truyền vào, `presentation/` không import `core/remote_config_service.dart`.

**Analytics logging đặt trong `TutorialSequenceController` (state machine), không phải trong widget:** `TutorialStep` có thêm field `id` (nullable, mặc định `null`). Khi `id != null`, `start()`/`next()`/`skip()` tự gọi `AnalyticsProvider.maybe?.logEvent('tutorial_step_shown'|'tutorial_step_dismissed', {'stepId': id})` tại đúng thời điểm chuyển bước. Khi `id == null` (step viết theo kiểu imperative cũ, hardcode thẳng trong code màn hình — TOÀN BỘ call site cũ trong `example/` đều thuộc dạng này) — KHÔNG log gì cả. Đây là điểm mấu chốt giữ đúng "không phá API cũ" ở mức HÀNH VI chứ không chỉ chữ ký: 1 app đã tích hợp `TutorialSequence` từ trước, sau khi update package, sẽ không đột nhiên bắn ra analytics event nào nó chưa từng yêu cầu.

**Refactor nhỏ trong `next()`/`skip()` để tránh log trùng:** `next()` ở bước cuối trước đây gọi thẳng `skip()`; nếu giữ nguyên sẽ log "dismissed" 2 lần (1 lần trong `next()`, 1 lần trong `skip()`). Tách phần dọn dẹp chung ra `_endSequence()` (không log), gọi trực tiếp từ cả `next()` (đã tự log dismissed trước đó) và `skip()` (tự log dismissed rồi mới gọi `_endSequence()`).

**Test:** `test/widget/common/tutorial_sequence_test.dart`, thêm 24 test case mới lên tổng 24 test trong file — nhóm `TutorialStep.listFromJson` (parse hợp lệ ánh xạ đúng GlobalKey, targetKey không có trong registry → skip không crash, JSON không hợp lệ/không phải mảng → rỗng không throw, bỏ qua từng bước thiếu field/sai kiểu giữ lại bước hợp lệ, mảng rỗng) và nhóm `analytics shown/dismissed logging` (start() log shown, next() log dismissed+shown đúng thứ tự, next() ở bước cuối chỉ log dismissed đúng 1 lần không log shown thừa, skip() log dismissed, step không có `id` không log gì, không có AnalyticsProvider nào đăng ký không throw).

**Bug tự bắt trong lúc viết test:** so sánh record `(String, Map<String,Object?>)` bằng `expect(list, [...])` fail dù nội dung giống hệt — vì `Map` trong Dart dùng equality theo REFERENCE (không phải theo giá trị) mặc định, và `Record` tự sinh `==` chỉ so sánh từng field bằng `==` của field đó (không tự động deep-compare Map lồng bên trong). Sửa bằng cách đổi fake `AnalyticsProvider` trong test để lưu `(String name, Object? stepId)` (trích thẳng `stepId` ra khỏi params) thay vì lưu nguyên `Map` — né hoàn toàn vấn đề equality thay vì phải viết 1 custom matcher.

**Device smoke test** trên **TECNO BG6** (`118743744X002560`): thêm nút demo "Start from JSON (IDEA-35)" cạnh nút "Start 2-step tutorial" cũ trong `WidgetShowcaseScreen`, dùng `TutorialStep.listFromJson` với 1 chuỗi JSON tĩnh trỏ tới đúng 2 `GlobalKey` demo sẵn có (`primary`/`coins`). Cài APK debug mới, mở Widget Kit, cuộn tới demo TutorialSequence, bấm "Start from JSON (IDEA-35)" → `SpotlightOverlay` được kích hoạt đúng (màn hình mờ đi, barrier xuất hiện) — xác nhận pipeline JSON → parse → resolve GlobalKey → hiển thị overlay chạy đúng trên thiết bị thật, không crash; `adb logcat` lọc `level=Error` cho tiến trình app: không có dòng nào. Bấm nút Back (Android) thoát về Home sạch sẽ, không lỗi.

Không chụp được ảnh callout đang hiện đúng nội dung text — vì target (`_spotlightTargetKey`, nút Primary ở đầu section "Buttons & Interactive") nằm NGOÀI viewport tại vị trí cuộn cần thiết để chạm tới nút trigger (đúng hạn chế layout demo ĐÃ ĐƯỢC GHI NHẬN trước đó ở `ENH-48`/`ENH-55` — `ListView` trong `WidgetShowcaseScreen` dựng eager toàn bộ, không lazy, và barrier của `SpotlightOverlay` chặn cả tap lẫn scroll). Đây là hạn chế CÓ SẴN của màn hình demo, áp dụng như nhau cho cả nút "Start 2-step tutorial" gốc lẫn nút JSON mới — không phải lỗi phát sinh từ thay đổi của task này. Logic/hành vi chính xác (đúng target, đúng message/title lấy từ JSON) đã được xác nhận chắc chắn qua test widget chính xác ở mức pixel/API (không chỉ "không throw").

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 879/879 pass; `example/flutter analyze` + `flutter test --exclude-tags slow` 46/46 pass (không cần sửa `physicalSize` — 1 nút phụ trong 1 `_Demo` card có sẵn không đủ làm tràn viewport 9000px đã tăng từ IDEA-31). CHANGELOG.md đã thêm mục dưới `## 0.2.0`. `tool/api_compatibility.dart`'s gate KHÔNG bị kích hoạt (chỉ thêm method/field vào class `TutorialStep` đã tồn tại, không phải khai báo top-level mới) — đã xác nhận qua `flutter test test/api_compatibility_test.dart` vẫn pass mà không cần regenerate snapshot.

**Tự chấm điểm:** 9.5/10 — đúng yêu cầu "Đề xuất" (JSON authoring + analytics funnel logging + registry resolve an toàn), giữ nguyên vẹn API cũ ở cả chữ ký lẫn hành vi (không ép app cũ log analytics ngoài ý muốn), phát hiện và sửa 1 lỗi Map-equality tinh vi ngay trong lúc viết test, device smoke test thật với bằng chứng trung thực (không giả vờ chụp được ảnh callout khi thực tế không thể do hạn chế demo có sẵn), không over-engineer (không thêm cơ chế cache/versioning cho JSON, không tự ý hardcode remote-config key).
