---
id: ENH-63
title: "AsyncActionGuard: hành vi maxQueueWait (timeout khi chờ hàng đợi runExclusive) chưa có test nào"
type: enhancement
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/utils/async_action_guard.dart` và `test/core/utils/async_action_guard_test.dart`)
---

## Vị trí
Sửa lỗi thiếu test — `lib/core/utils/async_action_guard.dart` (`AsyncActionGuard`), test tại `test/core/utils/async_action_guard_test.dart`.

## Hiện trạng
`AsyncActionGuard` có constructor param `maxQueueWait` (`Duration?`) — dùng trong `runExclusive` để giới hạn thời gian chờ hàng đợi (`await previous.timeout(wait)` thay vì `await previous` vô thời hạn khi `maxQueueWait` được truyền vào). Đây là nhánh code THẬT, không phải dead code (khác `_key`/comment rỗng) — nhưng `test/core/utils/async_action_guard_test.dart` hiện chỉ có đúng 2 test (`runSingleFlight` coalesce lỗi, `runExclusive` chạy tuần tự đúng thứ tự) và KHÔNG có bất kỳ test nào truyền `maxQueueWait` — nghĩa là toàn bộ nhánh timeout (`.timeout(wait)`, việc `TimeoutException` được throw đúng, việc hàng đợi được dọn dẹp đúng sau timeout để không kẹt vĩnh viễn) chưa từng được chạy qua 1 lần assert nào.

## Vì sao cần / Hậu quả
`EconomyWallet` (nơi dùng `AsyncActionGuard` duy nhất trong `lib/`) hiện không truyền `maxQueueWait` (`AsyncActionGuard()` mặc định `null`) — nghĩa là tính năng bounded-wait tồn tại nhưng chưa ai dùng VÀ chưa ai test. Nếu 1 consumer app sau này quyết định dùng `maxQueueWait` (ví dụ chặn 1 hành động mua hàng không được chờ hàng đợi quá 5 giây), họ sẽ dựa vào 1 đường code chưa từng được xác nhận hoạt động đúng — rủi ro cụ thể nhất: nếu `_exclusiveTails[key]` không được dọn dẹp đúng sau khi 1 lệnh gọi timeout ra ngoài (thay vì hoàn thành bình thường qua nhánh `finally`), các lệnh gọi `runExclusive` SAU ĐÓ cho cùng `key` có thể bị kẹt chờ mãi mãi 1 Future không bao giờ hoàn tất — 1 lỗi rất khó phát hiện qua test thủ công vì chỉ lộ ra khi có timeout thật xảy ra.

## Đề xuất
Thêm test cho `maxQueueWait`, không đổi bất kỳ dòng implementation nào trừ khi test phát hiện đúng có bug (đọc kỹ nhánh `finally` trong `runExclusive` trước — có vẻ đã dọn dẹp đúng qua `completer.complete()`/`identical(...)` check, nhưng cần test THẬT để xác nhận thay vì đọc code suông):
- 1 `runExclusive` gọi với `key` đang bị 1 lệnh gọi trước đó (chưa hoàn thành) giữ chỗ lâu hơn `maxQueueWait` → lệnh gọi sau phải nhận `TimeoutException` (không phải treo vô hạn).
- Sau khi 1 lệnh gọi timeout ra ngoài, 1 lệnh gọi `runExclusive` MỚI cho ĐÚNG `key` đó (không liên quan gì tới lệnh đã timeout) vẫn phải chạy được bình thường — không bị kẹt bởi hàng đợi cũ đã timeout.
- `pendingCount` vẫn phản ánh đúng sau khi có 1 lệnh timeout (không bị "rò rỉ" đếm sai).
- `maxQueueWait == null` (giá trị mặc định, hành vi hiện có): vẫn chờ vô thời hạn như cũ, không đổi — test hồi quy đảm bảo default không bị phá khi thêm test mới.

## Acceptance criteria
- [x] `runExclusive` với `maxQueueWait` được truyền: 1 lệnh gọi phải chờ hàng đợi lâu hơn `maxQueueWait` nhận đúng `TimeoutException`, không treo vô hạn.
- [x] Sau 1 lệnh gọi timeout, `runExclusive` MỚI cho CÙNG `key` vẫn chạy đúng, không bị kẹt bởi hàng đợi cũ.
- [x] `pendingCount` không bị sai lệch sau khi có lệnh gọi timeout.
- [x] `maxQueueWait == null` (mặc định): hành vi chờ vô thời hạn không đổi — test hồi quy.
- [x] Nếu phát hiện bug thật trong nhánh timeout khi viết test (ví dụ hàng đợi không dọn dẹp đúng, gây kẹt vĩnh viễn) — sửa bằng TDD, không chỉ dừng ở việc thêm test cho code có sẵn.
- [x] Không phá 2 test hiện có (`runSingleFlight`/`runExclusive` cơ bản).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không cần đụng `example/` — tiện ích nội bộ thuần, không có UI liên quan.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-63-async-action-guard-max-queue-wait-untested.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/utils/async_action_guard.dart` (đặc biệt nhánh `finally` trong `runExclusive` và cách `_exclusiveTails` được dọn dẹp) và `test/core/utils/async_action_guard_test.dart` hiện có trước khi viết test mới. Dùng `fakeAsync`/`FakeAsync` (package `fake_async`, nếu đã có trong `pubspec.yaml`/`dev_dependencies` — kiểm tra trước; nếu chưa có, dùng `Duration` rất ngắn thật (vài chục ms) với `Future.delayed` thay vì thêm dependency mới) để test timeout mà không phải chờ đồng hồ thật quá lâu trong test suite.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — đây là task LẤP LỖ HỔNG TEST, ưu tiên viết test đúng và đủ; chỉ sửa implementation nếu test thật sự phát hiện bug).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần đụng `example/`/device smoke test — tiện ích nội bộ thuần (`lib/core/utils/`), không có UI, không đụng file nhạy cảm/scope peer.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `async_action_guard.dart`: `maxQueueWait` là field/tham số thật, được dùng thật trong `runExclusive` (`previous.timeout(wait)`), không phải dead code. Xác nhận qua đọc `test/core/utils/async_action_guard_test.dart` (chỉ 2 test, grep `maxQueueWait` trong file test ra kết quả rỗng) rằng nhánh này chưa từng được test. Xác nhận `EconomyWallet` (consumer duy nhất trong `lib/`) không truyền `maxQueueWait`, nên đây là code "có thật, chưa dùng, chưa test" — đúng dạng gap đã từng được các task BUG-10/ENH-36/ENH-06/ENH-12/IDEA-11 trước đây trong repo này xác nhận là hợp lệ để thành task riêng. Effort nhỏ (chỉ thêm test, có thể không cần sửa implementation nếu code đã đúng), không đụng file nhạy cảm/scope peer.

## Quyết định

Đọc kỹ nhánh `finally` trong `runExclusive` trước khi viết test (đúng yêu cầu trong Prompt) — phân tích: `completer.complete()` LUÔN chạy (Dart `finally` đảm bảo), nên không có future nào trong `_exclusiveTails` có thể "treo vĩnh viễn không bao giờ complete". `identical(_exclusiveTails[key], completer.future)` là 1 snapshot đồng bộ (không có `await` nào giữa lúc exception ném ra và lúc `finally` chạy), nên không có race condition giữa các lệnh gọi chồng lấn. Sau khi phân tích, viết đủ 4 test theo đúng Acceptance criteria — **cả 4 đều PASS ngay từ lần chạy đầu tiên, không phát hiện bug nào** — xác nhận implementation hiện có đã đúng, đây là task "lấp lỗ hổng test", không phải sửa lỗi.

Dùng `testWidgets` + `tester.pump(duration)` thay vì thêm `fake_async` làm dependency mới — `Future.delayed`/`Future.timeout`'s `Timer` nội bộ đều được `TestWidgetsFlutterBinding` giả lập, nên không cần chờ đồng hồ thật (đúng gợi ý trong Prompt: `fake_async` chỉ có trong `pubspec.lock` dạng transitive, không phải dependency trực tiếp, nên không import).

**Hành vi xác nhận đúng qua test**: sau khi 1 lệnh gọi timeout, nó tự dọn dẹp đúng khỏi `_exclusiveTails` (nếu không có ai queue sau nó) — nghĩa là 1 lệnh gọi MỚI cho cùng `key` sẽ KHÔNG chờ hành động cũ đã "kẹt" (đúng thiết kế: mục đích của `maxQueueWait` chính là để tránh việc 1 hành động treo vĩnh viễn làm nghẽn toàn bộ hàng đợi sau đó — không phải bug, mà là tính năng).

**Test:** 4 test mới trong `test/core/utils/async_action_guard_test.dart` nhóm "ENH-63" — timeout ném đúng `TimeoutException`, lệnh gọi mới không bị kẹt bởi hàng đợi cũ đã timeout, `pendingCount` không rò rỉ, và test hồi quy xác nhận `maxQueueWait == null` vẫn chờ vô thời hạn như cũ (dùng khoảng thời gian 250ms — dài hơn hẳn 50ms dùng làm `maxQueueWait` ở các test khác — để chắc chắn bắt được nếu implementation lỡ áp dụng timeout ngầm nào đó).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1127/1127 pass. Không đụng `implementation`/`example/` — đúng theo Prompt, đây thuần là tiện ích nội bộ không có UI, và code hiện có đã đúng nên không cần sửa gì.

**Tự chấm điểm: 9.5/10** — đủ mọi acceptance criteria, phân tích đúng logic đồng bộ trước khi viết test (không chỉ viết test mù quáng), xác nhận trung thực rằng code đã đúng thay vì cố tìm/bịa ra 1 bug không tồn tại để có gì đó "sửa". Trừ điểm nhỏ vì đây là task thuần bổ sung test (an toàn, ít rủi ro, không có thử thách kỹ thuật lớn để thể hiện thêm).
