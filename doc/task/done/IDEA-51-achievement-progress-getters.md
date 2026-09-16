---
id: IDEA-51
title: "AchievementService: progressOf/thresholdOf getters cho progress-bar UI"
type: idea
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/achievement_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/achievement_service.dart` (`AchievementService`).

## Hiện trạng
`AchievementService` chỉ public hoá `isCompleted(achievementId)` (bool) và `onUnlock` (stream lúc unlock). KHÔNG có cách nào đọc được tiến độ hiện tại (`_progressMap[achievementId]`) hay ngưỡng đã đăng ký (`_thresholds[achievementId]`) từ bên ngoài — cả 2 đều là field private. Một UI kiểu "Đã diệt 7/10 quái" (progress bar cho achievement chưa hoàn thành) không có cách nào lấy đúng 2 con số đó từ service.

## Vì sao cần / Hậu quả
`ProgressBarStars`/`CircularProgressRing` (đã có sẵn trong widget kit) đều nhận `value` từ bên ngoài — nghĩa là 1 consumer app muốn hiện tiến độ achievement bằng các widget này phải tự lưu tiến độ // ngưỡng ở nơi khác (trùng lặp với chính state mà `AchievementService` đã lưu), hoặc dùng phản xạ/hack để đọc field private — cả 2 đều dở. Đây là khoảng trống rõ ràng giữa 1 service đã có sẵn state đúng và 1 bộ widget progress-bar đã có sẵn, chỉ thiếu cầu nối.

## Đề xuất
Thêm 2 getter công khai, không đổi hành vi hiện có:
- `int progressOf(String achievementId)` — trả về tiến độ hiện tại, `0` nếu chưa từng `incrementProgress`, không throw kể cả id chưa từng `register`.
- `int? thresholdOf(String achievementId)` — trả về ngưỡng đã `register`, `null` nếu chưa từng đăng ký (khác `isCompleted` vốn coi "chưa đăng ký" là `false`, ở đây cần phân biệt rõ "chưa đăng ký" với "đã đăng ký, ngưỡng > 0").

## Acceptance criteria
- [x] `progressOf` trả về đúng giá trị hiện tại (khớp với những gì `incrementProgress` đã cộng dồn), `0` cho achievement chưa từng có progress, không throw cho id chưa từng `register`.
- [x] `thresholdOf` trả về đúng ngưỡng đã `register`, `null` cho id chưa từng đăng ký.
- [x] `progressOf`/`thresholdOf` với achievementId rỗng/blank: xử lý nhất quán với các method khác trong class (validate + throw `ArgumentError`, giống `_validateId` hiện có — không âm thầm trả về giá trị mặc định cho input không hợp lệ).
- [x] Không đổi hành vi `incrementProgress`/`isCompleted`/`onUnlock`/`register` hiện có; không phá test cũ.
- [x] Test: unit test đầy đủ mọi case trên, bao gồm sau khi hoàn thành achievement (`progressOf` vẫn tiếp tục phản ánh đúng, không bị khoá ở đúng threshold).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/` — nếu muốn minh hoạ, cân nhắc wire vào 1 demo progress bar cho achievement trong `widget_showcase_screen.dart` (không bắt buộc).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-51-achievement-progress-getters.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/achievement_service.dart` và `test/core/achievement_service_test.dart` hiện có để hiểu đúng convention validate/error hiện tại trước khi thêm getter mới. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — chỉ 2 getter đơn giản, không thêm cấu trúc mới).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Cân nhắc có nên wire vào demo `example/lib/screens/widget_showcase_screen.dart` hay không (không bắt buộc — nếu làm, phải test + device smoke test cho phần đó).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (và `example/` nếu có đụng tới).
5. Nếu có đụng tới `example/` để demo: smoke test thật trên máy Android/iOS thật hiện có (kiểm tra `mobile_list_available_devices` trước, dùng thiết bị đang online — KHÔNG dùng simulator/emulator), chụp screenshot làm bằng chứng, ghi vào `## Quyết định`. Thiết bị có thể đang chia sẻ với peer session khác — kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `achievement_service.dart`: chỉ `isCompleted`/`onUnlock`/`register`/`incrementProgress` là public, `_progressMap`/`_thresholds` đều private, không có getter nào đọc được số. Effort nhỏ (2 getter thuần), không đụng file nhạy cảm/scope peer.

## Quyết định

Thêm đúng 2 getter thuần như đề xuất, tái dùng `_validateId` (đã có sẵn, dùng chung với `register`/`incrementProgress`/`isCompleted`) — không viết logic validate riêng:

- `progressOf(id)` → `_progressMap[id] ?? 0`. Không "khoá" ở threshold — phản ánh đúng giá trị tích luỹ thật kể cả sau khi đã hoàn thành (đã có test riêng xác nhận: hoàn thành ở 5/5 rồi cộng thêm 3 → `progressOf` trả về 8, không kẹt ở 5).
- `thresholdOf(id)` → `_thresholds[id]` (nullable, phân biệt rõ "chưa từng `register`" khỏi "đã `register` với ngưỡng cụ thể" — khác hẳn `isCompleted` vốn coi cả 2 trường hợp là `false`).

Không đụng bất kỳ logic nào của `incrementProgress`/`isCompleted`/`onUnlock`/`register`.

**Test:** 5 test mới trong `test/core/achievement_service_test.dart` nhóm "IDEA-51" — `progressOf` mặc định 0 không throw, cộng dồn đúng, không bị khoá sau khi hoàn thành; `thresholdOf` null khi chưa register, đúng giá trị khi đã register; cả 2 throw `ArgumentError` cho id rỗng/blank.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1110/1110 pass. Không đụng `example/` — quyết định không demo (đúng "không bắt buộc" trong Prompt): đây là 2 getter đơn giản, giá trị minh hoạ qua UI không tương xứng với chi phí dựng thêm 1 progress-bar achievement demo mới trong màn hình vốn đã rất dài.

**Tự chấm điểm: 9.5/10** — đúng mọi acceptance criteria, tái dùng triệt để `_validateId` có sẵn, không thêm cấu trúc dữ liệu mới, phân biệt đúng ngữ nghĩa `progressOf` (mặc định 0) và `thresholdOf` (nullable) đúng như yêu cầu — đây là điểm dễ làm sai nếu không đọc kỹ đề xuất. Trừ điểm nhỏ vì không có bằng chứng device thật (không cần thiết cho thay đổi core-service-thuần không có UI, nhưng vẫn là 1 hình thức bằng chứng ít hơn các task khác trong session này).
