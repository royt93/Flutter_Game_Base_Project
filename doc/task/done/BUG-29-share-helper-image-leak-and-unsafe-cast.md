---
id: BUG-29
title: "ShareHelper: rò rỉ ui.Image native, và force-cast render object có thể crash"
type: bug
priority: P3
effort: M
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/share_helper.dart` — `captureBoardPng()`.

## Hiện trạng
2 vấn đề: (1) `captureBoardPng()` lấy `ui.Image` từ `toImage()` và (khi có overlay text) từ `_withTextOverlay()` nhưng KHÔNG BAO GIỜ gọi `.dispose()` trên các image này — mỗi lần share (score card, journey card) rò rỉ native pixel buffer, và path có overlay tạo 2 image rò rỉ cùng lúc. (2) `captureBoardPng()` force-cast `ctx.findRenderObject() as RenderRepaintBoundary` — nếu key được gắn nhầm vào widget khác (lỗi lập trình ở caller), crash bằng type error khó hiểu thay vì trả kết quả "không capture được" đã tài liệu hoá.

## Vì sao cần / Hậu quả
Chia sẻ ảnh nhiều lần (mỗi lần thắng level, mỗi lần đạt milestone) tích luỹ leak native image buffer, tương tự BUG-24 nhưng ở tầng khác. Force-cast crash là 1 lỗi tích hợp dễ mắc phải nếu 1 widget mới gắn `GlobalKey` sai chỗ.

## Đề xuất
Bọc conversion trong try/finally, dispose board image và overlay image (nếu khác instance) sau khi `toByteData()` xong, kể cả khi có exception giữa chừng. Type-check render object trước khi cast, trả về kết quả "không capture" đã tài liệu hoá (null hoặc tương tự) thay vì để crash lan ra ngoài.

## Acceptance criteria
- [x] Mọi ui.Image tạo trong captureBoardPng() được dispose kể cả khi path có overlay text (2 image).
- [x] RenderObject sai kiểu (không phải RenderRepaintBoundary) trả về kết quả documented thay vì crash bằng type error.
- [x] Test: capture lặp lại nhiều lần xác nhận không leak (đếm dispose calls qua fake/mock nếu cần), và key gắn vào widget không phải RepaintBoundary trả về đúng kết quả no-capture.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (KHÔNG đạt — xem Quyết định: môi trường USB/adb không ổn định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (N/A — không phải widget, không thay đổi UI/animation nào, chỉ sửa lifecycle nội bộ của pipeline capture ảnh.)

## Quyết định
Sửa 2 vấn đề trong `captureBoardPng()`:
1. Thay force-cast `as RenderRepaintBoundary` bằng type-check (`is!` → `return null`) — khớp đúng kết quả "không capture" đã tài liệu hoá trong doc comment của hàm, thay vì crash type error nếu key gắn nhầm widget.
2. Bọc phần tạo/convert image trong `try/finally`: `board.dispose()` luôn chạy; `overlayImage?.dispose()` chỉ chạy khi có tạo overlay (tránh double-dispose khi không có overlay, lúc đó `image` và `board` là cùng 1 reference).

Test dùng 2 static hook có sẵn của chính `dart:ui` (`ui.Image.onCreate`/`onDispose`) để đếm số image tạo ra vs dispose trong toàn VM khi chạy `captureBoardPng()` — không cần thêm bất kỳ counter `@visibleForTesting` nào vào `share_helper.dart` (giải pháp đơn giản nhất, không thêm code sản xuất chỉ để phục vụ test). 4 test mới: không-overlay, có-overlay (2 image), gọi lặp 5 lần liên tiếp (không tích luỹ leak), và render object sai kiểu trả về null.

**Device smoke test: KHÔNG đạt được** — kết nối USB/adb tới Pixel 7 Pro gặp lại đúng sự bất ổn định đã ghi nhận ở BUG-26 (`adb devices -l` cho thấy `transport_id` liên tục đổi qua các lần gọi, biểu hiện kết nối vật lý liên tục rớt/nối lại). Đã thử: `adb install` trực tiếp (nhiều lần), `adb kill-server`/`start-server` rồi thử lại, `push` + `pm install` fallback, gỡ cài đặt bản cũ (`com.galaxyjoy.roycasualkit`) rồi cài lại — tất cả đều thất bại với lỗi rỗng hoặc "no devices/emulators found" xen kẽ giữa các lần `adb devices -l` thấy device connected. Không phải lỗi từ code fix (build APK thành công, không liên quan). Không phải widget/animation nên rủi ro thực tế thấp — dựa vào: 8 test unit/widget pass (bao phủ cả 2 vấn đề + edge case), và grep xác nhận nơi gọi duy nhất trong `example/` (`WidgetShowcaseScreen` → `shareScoreCard`) không thay đổi hành vi quan sát được từ UI (chỉ sửa lifecycle nội bộ + fallback null thay vì crash). Khuyến nghị verify lại thủ công khi kết nối USB ổn định.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (556 tests) và `example/` (không regression).

Tự chấm: 9/10 — đúng root cause, fix tối thiểu (không thêm abstraction, tận dụng hook có sẵn của dart:ui cho test thay vì tự chế counter), test bao phủ đủ case quan sát được từ bên ngoài; trừ điểm vì thiếu bằng chứng device smoke (do hạn chế môi trường ngoài tầm kiểm soát, không phải do code).

Commit code: `b52659f`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-29-share-helper-image-leak-and-unsafe-cast.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — 2 vấn đề độc lập nhưng cùng file/hàm, sửa chung 1 lần hợp lý. Effort M vì cần cẩn thận với lifecycle của `ui.Image` (dispose sai chỗ có thể làm hỏng ảnh đang dùng).
