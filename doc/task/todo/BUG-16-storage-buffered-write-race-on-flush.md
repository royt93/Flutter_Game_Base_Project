---
id: BUG-16
title: "StorageService: flush() có thể mất write mới nếu ghi đè lên buffer đang chờ I/O"
type: bug
priority: P2
effort: M
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/storage_service.dart` — `flush()` và `setIntBuffered`/`setStringBuffered`.

## Hiện trạng
`flush()` copy rồi clear `_buffer`, sau đó await từng disk write tuần tự. Mỗi lần `setInt`/`setString` (direct, unbuffered) chạy xong lại xoá key đó khỏi `_buffer`. Nếu 1 giá trị buffered MỚI cho cùng key đến trong lúc flush đang await I/O của giá trị CŨ, flush hoàn tất và xoá `_buffer` entry của giá trị mới đó — kết quả: giá trị mới bị mất, disk chỉ còn giá trị cũ.

## Vì sao cần / Hậu quả
Đây là buffer dùng cho hot-path counters (theo doc), nhưng nếu 2 lần set liên tiếp xảy ra đúng lúc app bị kill giữa chừng flush, counter có thể rollback về giá trị cũ hơn — im lặng, không log, khó debug. `test/core/storage_service_test.dart` hiện KHÔNG test buffer/flush path này (đã xác nhận qua audit), nên regression này vô hình với test suite.

## Đề xuất
Sửa flush() để chỉ xoá 1 entry khỏi `_buffer` nếu giá trị hiện tại trong buffer VẪN BẰNG giá trị vừa flush xong (so sánh trước khi remove), thay vì xoá vô điều kiện theo key. Hoặc đơn giản hơn: serialize mọi mutation của `_buffer` qua 1 hàng đợi (Future chain) để flush không bao giờ chạy song song với 1 write mới trên cùng key.

## Acceptance criteria
- [ ] flush() không còn làm mất giá trị buffered mới hơn khi 1 write mới đến giữa lúc flush đang await I/O.
- [ ] Test tái hiện đúng race: dùng SharedPreferences fake có thể trì hoãn write (delayed completer), set buffered value A, gọi flush() (chưa await xong), set buffered value B cho CÙNG key, để flush's I/O hoàn tất, xác nhận giá trị cuối cùng trên disk là B chứ không phải A.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-16-storage-buffered-write-race-on-flush.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — đây là race condition thật, xác nhận qua đọc code (không phải suy đoán), ảnh hưởng tới toàn bộ hot-path counter dùng buffer (ví dụ energy/currency nếu dùng buffered write). Effort M vì cần thiết kế lại cơ chế xoá buffer entry cẩn thận để không phá vỡ API hiện có.
