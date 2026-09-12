---
id: BUG-17
title: "AchievementService: các lần incrementProgress() liên tiếp có thể ghi đè nhau sai thứ tự"
type: bug
priority: P2
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/achievement_service.dart` — `incrementProgress()`.

## Hiện trạng
`incrementProgress()` cập nhật `_progressMap` trong bộ nhớ ngay lập tức (đồng bộ) nhưng gọi `_store.save(_progressMap)` với `unawaited` (fire-and-forget). Nếu app gọi `incrementProgress` nhiều lần rất nhanh (ví dụ combo nhiều event cùng lúc), các lệnh save chạy song song và write HOÀN TẤT không đảm bảo đúng thứ tự gọi — 1 save cũ có thể hoàn tất SAU 1 save mới hơn, ghi đè disk bằng snapshot cũ.

## Vì sao cần / Hậu quả
Người chơi thấy progress bị lùi lại (mất tiến độ achievement) sau khi restart app, dù trong session vẫn hiển thị đúng — bug khó tái hiện thủ công vì cần đúng timing I/O, chỉ lộ ra khi test có storage fake trì hoãn ghi có kiểm soát.

## Đề xuất
Serialize các lần save qua 1 `Future` chain (mỗi `incrementProgress` chờ save trước đó xong rồi mới bắt đầu save mới, hoặc dùng 1 debounce/coalesce đơn giản: chỉ giữ lại lệnh save cuối cùng, hủy lệnh đang chờ nếu có lệnh mới hơn tới trước khi nó bắt đầu ghi).

## Acceptance criteria
- [ ] Nhiều lệnh incrementProgress() gọi liên tiếp không còn thể ghi đè nhau sai thứ tự trên disk.
- [ ] Test dùng storage fake trì hoãn/đảo thứ tự hoàn tất write, xác nhận giá trị cuối cùng trên disk khớp với lệnh gọi SAU CÙNG, không phải theo thứ tự I/O hoàn tất.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-17-achievement-service-out-of-order-save-race.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — race condition thật, cùng root cause với BUG-18 (daily_login_service) nhưng khác file nên tách task riêng để dễ review/merge độc lập.
