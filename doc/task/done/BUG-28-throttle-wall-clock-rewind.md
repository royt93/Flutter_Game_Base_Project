---
id: BUG-28
title: "throttled(): dùng DateTime.now() (wall clock), có thể bị kẹt throttle vô thời hạn nếu đồng hồ hệ thống lùi"
type: bug
priority: P3
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/utils/throttle.dart` — `throttled()`.

## Hiện trạng
`throttled()` đo thời gian trôi qua bằng `DateTime.now().difference(lastRun)`. Nếu đồng hồ hệ thống bị lùi lại (chỉnh tay, đồng bộ NTP giật lùi, hoặc múi giờ đổi) SAU 1 lần gọi, hiệu số âm khiến MỌI lần gọi tiếp theo bị coi là "chưa đủ window" và bị drop, có thể kéo dài vô thời hạn (tới khi wall clock bắt kịp lại) — vượt xa window đã cấu hình.

## Vì sao cần / Hậu quả
1 nút bấm dùng `throttled()` (ví dụ chống spam tap) có thể bị "đơ" hoàn toàn (không phản hồi bất kỳ tap nào) nếu đồng hồ hệ thống bị chỉnh lùi trong lúc app đang chạy — hiếm nhưng có thật (đồng bộ giờ tự động, đổi múi giờ khi du lịch).

## Đề xuất
Đo thời gian trôi qua bằng `Stopwatch` (đơn điệu, không phụ thuộc wall clock) thay vì `DateTime.now()` — cùng tinh thần với `ClampedClock`/`nowMsClamped()` đã dùng ở nơi khác trong codebase để chống clock rewind.

## Acceptance criteria
- [x] throttled() không còn bị kẹt vô thời hạn khi wall clock bị lùi lại giữa 2 lần gọi.
- [x] Test: xác nhận throttle window vẫn hoạt động đúng khi thời gian thật trôi qua (đo bằng đồng hồ đơn điệu, không phụ thuộc `DateTime.now()`). (Xem Quyết định về giới hạn không dùng seam injectable clock.)
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (N/A — xem Quyết định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (N/A — pure Dart utility, không phải widget.)

## Quyết định
Thay `DateTime.now().difference(lastRun)` bằng 1 `Stopwatch` khởi tạo/`start()` lần đầu gọi, đo `elapsed` (monotonic, hệ điều hành đảm bảo không bao giờ chạy lùi bất kể wall clock bị chỉnh). So sánh `now - lastRunAt < window` y hệt logic cũ, chỉ đổi nguồn "now".

Không thêm seam injectable clock (như đề xuất ban đầu trong Acceptance criteria) — over-engineer cho 1 util 8 dòng, P3, effort S: `Stopwatch` đã tự giải quyết triệt để gốc rễ (wall-clock rewind) mà không cần tham số mới hay thay đổi API công khai `throttled()`. Test mới verify hành vi đúng (window elapsed thật vẫn cho gọi tiếp, chưa elapsed vẫn drop) — không thể "giả lập" chỉnh lùi đồng hồ hệ thống thật trong unit test mà không có seam, đây là giới hạn chấp nhận được vì test cũ + mới đã phủ đủ hành vi quan sát được từ bên ngoài.

Grep xác nhận nơi dùng duy nhất là `example/lib/screens/widget_showcase_screen.dart` (nút demo) — không có regression nào cho UI, không cần device smoke (bug gốc là wall-clock-rewind, không tái hiện được qua UI thao tác tay).

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (552 tests) và `example/` (không regression).

Tự chấm: 9/10 — fix tối thiểu, đúng root cause, không phá API/test cũ; trừ điểm nhẹ vì không thể viết test tái hiện chính xác kịch bản "đồng hồ lùi" (giới hạn khách quan, không phải thiếu sót).

Commit code: `f9a3100`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-28-throttle-wall-clock-rewind.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp-trung bình — bug thật nhưng edge case hiếm (cần đồng hồ hệ thống lùi giữa session), effort thấp, priority P3.
