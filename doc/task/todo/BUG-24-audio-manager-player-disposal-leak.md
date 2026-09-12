---
id: BUG-24
title: "AudioManager: BGM player không dispose khi service đóng, mọi SFX player không bao giờ dispose"
type: bug
priority: P2
effort: M
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/audio_manager.dart` — thiếu `onClose()`, và `playSfx()`.

## Hiện trạng
`AudioManager` (GetxService) không override `onClose()` để dispose `_bgm` (mà `dispose()` của `AudioPlayer` giải phóng cả binding observer) — nếu service từng bị `Get.delete` (không phải permanent) thì leak. Nghiêm trọng hơn: mỗi lần `playSfx()` tạo 1 `AudioPlayer` MỚI nhưng KHÔNG BAO GIỜ gọi `.dispose()` sau khi phát xong — mỗi tiếng SFX (chạm nút, combo, v.v — rất thường xuyên trong 1 casual game) rò rỉ 1 player kèm stream controller/subscription của nó.

## Vì sao cần / Hậu quả
Game chơi lâu (nhiều nút bấm phát SFX) sẽ tích luỹ hàng trăm/nghìn `AudioPlayer` instance leak, tăng dần memory usage — 1 class bug hiệu năng kinh điển, dễ bị bỏ sót vì không crash ngay lập tức, chỉ chậm dần theo thời gian chơi.

## Đề xuất
Override `onClose()` để dispose `_bgm`. Với `playSfx()`: dispose player trong `finally` sau khi phát xong (dùng `player.onPlayerComplete` listener rồi dispose, hoặc dispose ngay sau await complete future nếu API hỗ trợ) — cân nhắc thêm: nếu SFX được phát rất dồn dập, có thể cần 1 pool nhỏ tái sử dụng player thay vì tạo/huỷ liên tục, nhưng chỉ làm nếu profiling thật sự cho thấy cần (đừng over-engineer nếu dispose đơn giản đã đủ giải quyết leak).

## Acceptance criteria
- [ ] AudioManager.onClose() dispose _bgm đúng cách.
- [ ] Mỗi AudioPlayer tạo trong playSfx() được dispose sau khi phát xong (thành công), sau khi phát lỗi (exception), và khi service đóng giữa lúc đang phát.
- [ ] Test dùng fake/mock AudioPlayer xác nhận .dispose() được gọi đúng số lần trong cả 3 tình huống trên.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-24-audio-manager-player-disposal-leak.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — leak thật, dễ chứng minh bằng test đếm số lần dispose gọi trên 1 fake player. Effort M vì cần inject được player factory để test (audioplayers package có thể cần 1 seam nhỏ, hoặc dùng package's test utilities nếu có).
