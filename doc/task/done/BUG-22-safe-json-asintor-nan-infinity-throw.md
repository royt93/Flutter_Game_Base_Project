---
id: BUG-22
title: "safe_json.asIntOr(): throw UnsupportedError khi input là NaN/Infinity, vi phạm cam kết không throw"
type: bug
priority: P2
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/utils/safe_json.dart` — `asIntOr()`.

## Hiện trạng
`asIntOr()` gọi `.toInt()` cho mọi giá trị double mà không kiểm tra hữu hạn trước. `double.nan`, `double.infinity`, `double.negativeInfinity` đều ném `UnsupportedError` khi gọi `.toInt()` — vi phạm đúng cam kết của hàm này ("tolerant type-coercing reader...never throw" theo doc comment CLAUDE.md).

## Vì sao cần / Hậu quả
Đây là hàm chuyên dùng để đọc dữ liệu từ 1 map JSON đã decode có thể chứa field sai kiểu (theo doc, dùng cho `VersionedJsonStore` payload) — remote config hoặc save data hỏng có thể chứa NaN/Infinity (JSON chuẩn không có NaN nhưng nhiều adapter/serializer lỏng lẻo vẫn sinh ra được), làm crash đúng chỗ lẽ ra phải an toàn nhất.

## Đề xuất
Check `v.isFinite` trước khi gọi `.toInt()`; trả về fallback nếu không hữu hạn, giống hệt cách hàm này đã xử lý các trường hợp sai kiểu khác.

## Acceptance criteria
- [x] asIntOr() không throw với double.nan/infinity/negativeInfinity — trả về fallback đã cấu hình.
- [x] Test tường minh cho NaN, Infinity, -Infinity làm input.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Quyết định
Sửa đúng như Đề xuất: check `v.isFinite` trước khi gọi `.toInt()`, fallback
nếu không hữu hạn. 1 dòng thay đổi, đúng effort S dự kiến.

Test: 4 test mới (NaN, Infinity, -Infinity, xác nhận không throw qua
`returnsNormally`). Tổng 13 test trong file, tất cả pass. `flutter
analyze` sạch cả root + `example/`. `flutter test --exclude-tags slow`:
tất cả pass, không regression.

Không có device smoke test — pure Dart utility function, không render UI.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-22-safe-json-asintor-nan-infinity-throw.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao mức độ tin cậy (bug rõ ràng, dễ verify bằng 1 dòng code), effort thấp — sửa nhanh, nên làm sớm vì đây là 1 utility nền tảng dùng ở nhiều nơi khác.
