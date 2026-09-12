---
id: BUG-27
title: "OfflineProgressionService: tham số kinh tế âm/không hợp lệ có thể throw hoặc tạo phần thưởng NaN/âm"
type: bug
priority: P3
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/offline_progression_service.dart`.

## Hiện trạng
`maxOfflineCap` âm khiến `(now - last).clamp(0, negativeUpperBound)` throw (clamp với upper bound nhỏ hơn lower bound là lỗi runtime). Production rate âm hoặc không hữu hạn trả về earnings âm/NaN/vô cực — cả 2 tham số đều là input do caller (game logic) truyền vào trực tiếp, không được validate.

## Vì sao cần / Hậu quả
1 lỗi cấu hình đơn giản ở phía game (ví dụ rate tính sai thành âm do 1 công thức balance lỗi) có thể crash ngay lập tức khi tính offline earning, hoặc worse: âm thầm trừ tiền người chơi thay vì cộng.

## Đề xuất
Validate `maxOfflineCap >= 0` và rate hữu hạn + không âm ngay đầu hàm liên quan (ném `ArgumentError` trước khi đọc/sửa state claim) — lỗi cấu hình nên fail sớm và rõ ràng thay vì lan ra reward tính sai.

## Acceptance criteria
- [x] Tham số cap âm hoặc rate âm/không hữu hạn ném ArgumentError rõ ràng, không tính earnings sai hoặc crash mơ hồ.
- [x] Test: cap âm, rate âm, rate NaN/Infinity — xác nhận claim state (offlineLastClaimedMs) KHÔNG bị tiến lên khi validate fail.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (N/A — không có UI, xem Quyết định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (N/A — service Dart thuần, không phải widget.)

## Quyết định
Validate cả 2 tham số ngay đầu `_earningsAt()` (hàm dùng chung cho cả `pendingEarnings()` lẫn `claim()`): `maxOfflineCap.isNegative` và `!productionRatePerSecond.isFinite || productionRatePerSecond < 0` đều ném `ArgumentError.value(...)` trước khi đọc/tính bất kỳ state nào. Vì `claim()` gọi `_earningsAt()` trước dòng `setInt(StorageKeys.offlineLastClaimedMs, now)`, một lời gọi invalid không bao giờ advance mốc claim.

Thêm 4 test trong `group('BUG-27: ...')` tại `test/core/offline_progression_service_test.dart`: cap âm, rate âm, rate NaN/Infinity, và invalid `claim()` không advance `offlineLastClaimedMs`.

Grep toàn repo (`lib/`, `example/`) xác nhận không có call site nào truyền cap/rate không hợp lệ, và `OfflineProgressionService` không có UI/widget nào bọc nó trong `example/` — do đó bỏ qua device smoke test (N/A, không phải regression rủi ro cho người dùng thật).

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở cả root và `example/` (không regression).

Tự chấm: 9.5/10 — đúng yêu cầu, fix tối thiểu (validate tại 1 điểm dùng chung, không thêm abstraction thừa), test bao phủ đủ case, không phá test cũ.

Commit code: `ba1e83b`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-27-offline-progression-invalid-economic-params.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — bug rõ ràng, effort thấp, priority P3 vì đây là lỗi cấu hình phía caller (game logic), ít khả năng xảy ra với input hợp lệ thông thường.
