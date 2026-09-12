---
id: BUG-21
title: "weightedRandomPick: validate chỉ bằng assert (biến mất ở release build)"
type: bug
priority: P2
effort: S
source: Codex (codex exec, audit toàn diện lib/core/)
---

## Vị trí
`lib/core/utils/weighted_random_pick.dart`.

## Hiện trạng
Các kiểm tra độ dài list/không rỗng chỉ là `assert(...)` — bị strip hoàn toàn khỏi release build. Trọng số không được kiểm tra âm/NaN/vô cực/tổng bằng 0; các trường hợp này lọt qua và rơi vào `items.last` — kết quả xác định (deterministic) nhưng vô nghĩa về mặt toán học, im lặng không báo lỗi.

## Vì sao cần / Hậu quả
1 loot table cấu hình sai (ví dụ trọng số load từ remote config bị lỗi, tất cả = 0) khiến release build LUÔN LUÔN trả về phần tử cuối cùng của list — người chơi luôn nhận đúng 1 loại phần thưởng dù tưởng là ngẫu nhiên, và debug build không hề lộ vấn đề này ra (vì assert không chạy identical ở debug nếu điều kiện assert pass được — thực ra assert CÓ chạy ở debug, chỉ release mới strip, nên bug này cụ thể là 'debug catches it, release doesn't', dễ lọt qua QA nếu QA chỉ test debug build).

## Đề xuất
Thay assert bằng validate runtime thật (`ArgumentError`) cho: độ dài 2 list bằng nhau và không rỗng, mọi trọng số hữu hạn và không âm, tổng trọng số hữu hạn và > 0.

## Acceptance criteria
- [ ] Input không hợp lệ (list rỗng, độ dài lệch, trọng số âm/NaN/Infinity, tổng = 0) ném ArgumentError rõ ràng ở CẢ debug lẫn release build.
- [ ] Test vượt ra ngoài phạm vi assert hiện tại: list rỗng, tổng trọng số = 0, trọng số âm, NaN, Infinity.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-21-weighted-random-pick-release-mode-unsafe.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — bug thật, dễ sửa (effort S), nhưng cần xác nhận không widget/service nào đang cố tình dựa vào hành vi "im lặng trả về items.last" hiện tại trước khi đổi sang throw.
