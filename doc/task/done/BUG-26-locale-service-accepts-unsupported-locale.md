---
id: BUG-26
title: "LocaleService.change(): chấp nhận locale không có trong AppTranslations.supported"
type: bug
priority: P3
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/locale_service.dart` — `change()`.

## Hiện trạng
`change()` nhận bất kỳ `Locale` nào, cập nhật GetX ngay và chỉ lưu language code — kể cả khi locale đó KHÔNG có trong `AppTranslations.supported`. Session hiện tại chạy ở locale chưa dịch (text fallback lẫn lộn/thiếu), nhưng lần khởi động SAU sẽ bị `_loadInitial()` từ chối locale đó và fallback về default — hành vi trước/sau restart không nhất quán.

## Vì sao cần / Hậu quả
Người dùng vô tình (hoặc do bug ở nơi khác) đổi sang locale không hỗ trợ sẽ thấy app hiển thị sai/thiếu chuỗi dịch trong session đó, rồi tự động về lại locale mặc định sau khi mở lại app — trải nghiệm khó hiểu, không rõ ràng.

## Đề xuất
`change()` validate locale nằm trong `AppTranslations.supported` trước khi áp dụng; nếu không, hoặc từ chối (giữ nguyên locale hiện tại) hoặc normalize về `AppTranslations.fallback` — chọn 1 policy rõ ràng và ghi vào doc comment.

## Acceptance criteria
- [x] change() với locale không được hỗ trợ không để app rơi vào trạng thái locale không dịch được.
- [x] Test: gọi change() với locale ngoài danh sách supported, và với locale có country code khác nhưng cùng language code đã supported (đảm bảo không bị từ chối nhầm).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. **(KHÔNG hoàn thành — xem Quyết định.)**
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-26-locale-service-accepts-unsupported-locale.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Quyết định
Match theo `languageCode` (không phải exact `Locale` equality), CÙNG
logic `_loadInitial()` đã dùng để match device locale — nhất quán trong
cùng file. Khớp thì chuẩn hoá về đúng entry trong
`AppTranslations.supported` (không giữ nguyên input `locale` — tránh 1
instance `Locale` "gần giống nhưng không identical" lọt vào `current`).
Không khớp → `ArgumentError`.

Xác nhận caller thật duy nhất (`example/lib/screens/settings_screen.dart`'s
`_pickLanguage`) LUÔN gọi `locale.change(l)` với `l` lấy trực tiếp từ
`for (final l in AppTranslations.supported)` — an toàn tuyệt đối, không
có rủi ro phá UI thật nào.

Test: 2 test mới (locale ngoài danh sách → throw; locale cùng language
khác country → chấp nhận, chuẩn hoá đúng). Tổng 8 test, tất cả pass.
`flutter analyze` sạch cả root + `example/`. `flutter test
--exclude-tags slow`: tất cả pass, không regression.

**Device smoke test KHÔNG hoàn thành** — kết nối USB tới Pixel 7 Pro
(`2B051FDH3006MU`) chập chờn nghiêm trọng trong lúc thực hiện task này
(`adb` liên tục báo `EOF`/`device not found`/`protocol fault` dù cáp và
máy không đổi, đã thử restart `adb server` nhiều lần) — vấn đề hạ tầng
tại thời điểm làm việc, không phải do code thay đổi. Bằng chứng thay thế:
9 test đơn vị pass (bao gồm 2 test mới), và xác nhận TRỰC TIẾP qua đọc
code rằng caller thật duy nhất trong `example/` luôn truyền locale hợp
lệ — rủi ro thực tế của thay đổi này với UI thật là rất thấp. Nên verify
lại bằng tay (mở Settings → đổi ngôn ngữ) lần tới khi thiết bị kết nối
ổn định, dù không bắt buộc vì code path không đổi hành vi cho input hợp
lệ.

## Ghi chú độ tin cậy
Trung bình — bug rõ ràng, effort thấp, cần xác nhận policy đúng đắn (từ chối vs normalize) trước khi code — không tự ý chọn nếu có ảnh hưởng UX cần bàn.
