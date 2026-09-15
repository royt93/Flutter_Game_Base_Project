---
id: IDEA-46
title: "Wire LocalScoreboardService thật vào demo LeaderboardList (thay data hardcode)"
type: idea
priority: exclusive (độ tin cậy cao)
effort: S/M
source: Claude (self-generated backlog brainstorm đợt 2 — xác nhận qua grep trực tiếp, không phỏng đoán)
---

## Vị trí
Mở rộng — `example/lib/screens/widget_showcase_screen.dart` (demo `LeaderboardList` hiện có).

## Hiện trạng
`LocalScoreboardService` (IDEA-30) tự nhận trong CHANGELOG chính nó: "`topN(n)` trả về `LeaderboardEntry` trực tiếp... sẵn sàng feed thẳng vào `LeaderboardList`". Nhưng grep xác nhận demo `LeaderboardList` hiện tại trong `widget_showcase_screen.dart` dùng data HARDCODE (Alice/You/Charlie cố định) — không hề gọi `LocalScoreboardService` dù 2 thứ được thiết kế khớp nhau ngay từ đầu (đúng interface `LeaderboardEntry`).

## Vì sao cần / Hậu quả
Demo hiện tại không chứng minh được lời hứa "feed thẳng, không cần transform" của `LocalScoreboardService` — người đọc `widget_showcase_screen.dart` để học cách dùng 2 thứ này cùng nhau sẽ không thấy ví dụ thật nào, phải tự suy luận.

## Đề xuất
Thay data hardcode bằng `LocalScoreboardService` thật: đăng ký service (giống pattern các service khác trong `initState`), `submitScore` vài điểm mẫu ban đầu, hiển thị `topN(3)` trực tiếp vào `LeaderboardList`. Thêm 1 nút "Submit random score" để demo trực quan bảng xếp hạng tự sắp xếp lại đúng khi có điểm mới.

## Acceptance criteria
- [ ] Demo `LeaderboardList` đọc dữ liệu thật từ `LocalScoreboardService.topN(...)`, không còn data hardcode.
- [ ] Bấm nút submit điểm mới → bảng cập nhật đúng thứ tự (điểm cao hơn lên trên), UI rebuild đúng.
- [ ] Không phá test hiện có của `widget_showcase_screen_test.dart` (đã dùng data cũ ở 1 vài assertion, cần cập nhật nếu có).
- [ ] Test: widget test cho phần demo mới (submit → rebuild đúng thứ tự).
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên thiết bị Android thật hiện có (không simulator) — bằng chứng cụ thể trong Quyết định.
- [ ] Không có animation mới cần thiết ngoài animation sẵn có của `LeaderboardList`/`CommonButton`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-46-wire-local-scoreboard-demo.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case) — widget test dựng widget thật và assert đúng hành vi/state.
3. Nếu có UI/widget tương tác người dùng: tôn trọng animation/reducedMotion đã có sẵn của `LeaderboardList`/`CommonButton`, không cần thêm animation mới.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật hiện có (kiểm tra `mobile_list_available_devices` trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot làm bằng chứng cụ thể, ghi lại trong `## Quyết định`. Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua grep trực tiếp: demo hiện tại hardcode, service đã thiết kế sẵn để khớp interface, chỉ cần wire lại, không cần thiết kế API mới. Effort nhỏ, không đụng file nhạy cảm/scope peer.
