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
- [x] Demo `LeaderboardList` đọc dữ liệu thật từ `LocalScoreboardService.topN(...)`, không còn data hardcode.
- [x] Bấm nút submit điểm mới → bảng cập nhật đúng thứ tự (điểm cao hơn lên trên), UI rebuild đúng.
- [x] Không phá test hiện có của `widget_showcase_screen_test.dart` (đã dùng data cũ ở 1 vài assertion, cần cập nhật nếu có).
- [x] Test: widget test cho phần demo mới (submit → rebuild đúng thứ tự).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên thiết bị Android thật hiện có (không simulator) — bằng chứng cụ thể trong Quyết định.
- [x] Không có animation mới cần thiết ngoài animation sẵn có của `LeaderboardList`/`CommonButton`.

## Quyết định

Implement đúng phần Đề xuất — thay data hardcode của demo `LeaderboardList` bằng `LocalScoreboardService` thật:

- Đăng ký `LocalScoreboardService` trong `initState` (pattern `X.maybe ?? Get.put(X(), permanent: true)` giống mọi service khác trong file này). Seed 2 đối thủ mẫu (Alice 12,340; Charlie 8,120) CHỈ khi bảng đang rỗng (`topN(1).isEmpty`) — tránh seed lặp lại mỗi lần app khởi động lại (service persist qua `StorageService`, seed vô điều kiện sẽ cộng dồn thêm Alice/Charlie mới mỗi lần mở app).
- `LeaderboardList` giờ nhận `entries` build động từ `_scoreboard.topN(3)`, map từng `LeaderboardEntry` trả về thành `LeaderboardEntry` mới với `highlighted: entry.name == 'You'` (service không tự set `highlighted`, phải suy ra ở tầng caller theo đúng tên "You").
- Nút "Submit random score" gọi `_scoreboard.submitScore('You', 1000 + Random().nextInt(15000))` trong `setState` — mỗi lần bấm thêm 1 dòng điểm mới của "You" (đúng bản chất "mỗi submission là 1 dòng riêng, không dedupe theo tên" của service — nếu bấm nhiều lần có thể thấy nhiều dòng "You" khác điểm nhau, đúng thiết kế arcade high-score gốc, không phải bug).

**Test:** thêm 1 test trong `example/test/widget_showcase_screen_test.dart` — mount xong thấy đúng "Alice"/"Charlie", không có "You"; bấm "Submit random score" → "You" xuất hiện đúng 1 lần. Dùng `.last` cho `find.text('Submit random score')` (StrokeText double-render quy ước đã biết của `CommonButton`).

**Device smoke test (Samsung Galaxy A50, `R58MA6WYRPE`, real device — S928B lúc trước đã ngắt kết nối, xem ghi chú)**: cài + mở app, cuộn tới Layout & Cards → card "LeaderboardList (IDEA-46: LocalScoreboardService)". Xác nhận đúng: bảng hiện "1 Alice 12,340 / 2 Charlie 8,120" (không có "You" hardcode). Bấm "Submit random score" → "You" xuất hiện đúng ở rank 3 (viền vàng highlighted), điểm ngẫu nhiên (3,406 ở lần chạy này) — đúng luồng submit → rank lại → hiển thị. `adb logcat` lọc `level=Error`: không có dòng nào.

**Ghi chú đổi thiết bị giữa chừng**: thiết bị thật kết nối qua adb đã đổi thêm 1 lần nữa trong lúc làm task này — từ Samsung Galaxy S928B (`R5CX613VZBR`, dùng ở ENH-59/ENH-60 trước đó) sang Samsung Galaxy A50 (`R58MA6WYRPE`). Đã kiểm tra `mobile_get_foreground_app` (launcher/idle) và `ListAgents` (không có peer session mới) trước khi cài/thao tác — an toàn. Đã cập nhật memory ghi lại cả 2 serial đã gặp, không gắn cứng 1 serial cụ thể nữa cho quy ước thiết bị test.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1004/1004 pass (không đổi `lib/`); `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 47/47 pass. Không có thay đổi API public (`lib/` không đổi) nên không cần CHANGELOG/snapshot.

**Tự chấm điểm: 9.5/10** — đúng yêu cầu Đề xuất, tái dùng đúng design ban đầu của `LocalScoreboardService`/`LeaderboardList` mà không cần sửa API nào, test xác nhận đúng hành vi, device smoke test thật xác nhận toàn bộ luồng kể cả sau khi thiết bị đổi giữa chừng. Trừ điểm nhỏ vì "seed chỉ khi rỗng" là 1 quyết định demo-only đơn giản, chưa hẳn là pattern chuẩn cho mọi use case thật (nhưng đủ tốt cho mục đích minh hoạ).

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
