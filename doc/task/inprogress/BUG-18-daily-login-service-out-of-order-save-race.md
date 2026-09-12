---
id: BUG-18
title: "DailyLoginService: claimToday() liên tiếp có thể rollback streak về trạng thái cũ"
type: bug
priority: P2
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/daily_login_service.dart` — `claimToday()`.

## Hiện trạng
Giống hệt root cause của BUG-17 nhưng ở service khác: `claimToday()` cập nhật `_cached` đồng bộ nhưng fire-and-forget `_store.save(...)`. Nếu 2 lần claim (kể cả trong test mô phỏng qua nhiều ngày liên tiếp) chồng lấp I/O, save cũ hoàn tất sau save mới sẽ ghi đè streak mới hơn bằng dữ liệu cũ hơn trên disk.

## Vì sao cần / Hậu quả
Restart app có thể làm streak bị rollback, khiến phần thưởng ngày đã claim trở nên claimable lại — lỗi nghiêm trọng về game economy (double-claim reward).

## Đề xuất
Serialize save qua 1 `Future` chain giống cách sửa BUG-17 (cân nhắc factor chung logic này ra 1 helper nhỏ dùng lại được ở cả 2 service nếu hợp lý, nhưng không bắt buộc — tránh over-engineer nếu chỉ 2 chỗ dùng).

## Acceptance criteria
- [ ] claimToday() gọi liên tiếp/nhanh không còn thể rollback streak trên disk.
- [ ] Test dùng storage fake trì hoãn write mô phỏng nhiều ngày claim liên tiếp với thứ tự hoàn tất I/O bị đảo lộn, xác nhận state cuối cùng sau khi hydrate lại từ disk khớp với lần claim SAU CÙNG.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-18-daily-login-service-out-of-order-save-race.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — race condition thật, ảnh hưởng trực tiếp tới reward economy (double-claim risk).
