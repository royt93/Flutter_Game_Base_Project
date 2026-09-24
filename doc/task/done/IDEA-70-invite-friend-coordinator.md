---
id: IDEA-70
title: "InviteFriendCoordinator — ghép fnv1a + share_helper + DeepLinkCommandRouter thành vòng lặp mời bạn bè"
type: feature
priority: low
effort: M
source: "claude (fork brainstorm, độc lập)"
---

## Vị trí
Mới: `lib/core/invite_friend_coordinator.dart`. Ghép 3 mảnh đã có: `lib/core/utils/fnv1a.dart` (`fnv1aHash`), `lib/core/share_helper.dart` (share text/link), `lib/core/deep_link_command_router.dart` (`DeepLinkCommandRouter`/`DeepLinkRoute`/`DeepLinkCommand`, nhận `myapp://invite?code=X` khi bạn mở app).

## Hiện trạng
`fnv1a.dart` chỉ là 1 hàm hash thuần (`fnv1aHash(String) -> int`), dùng cho `ExperimentBucketingService`. `share_helper.dart` chỉ share text/ảnh thuần, không biết gì về "mã mời". `deep_link_command_router.dart` chỉ định tuyến lệnh chung theo `DeepLinkRoute` (scheme/host/pathSegments → `commandType`), không có route/handler nào cho "invite" sẵn. Không mảnh nào biết về khái niệm "mã mời" hay "đã được mời bởi ai" — `grep -rn "invite" lib/core/` không ra kết quả liên quan.

## Vì sao cần / Hậu quả
Vòng lặp mời bạn (referral/viral loop) là cơ chế tăng trưởng kinh điển của casual game. Package đã có ĐỦ 3 mảnh hạ tầng cần thiết nhưng chưa ai ghép — đúng tinh thần "differentiator = ghép nối hạ tầng có sẵn" mà IDEA-66 đã chứng minh giá trị.

## Đề xuất
`InviteFriendCoordinator`: sinh mã mời ỔN ĐỊNH từ 1 id người chơi (dùng `fnv1aHash` — cùng id luôn ra cùng mã), cung cấp helper share mã đó qua `share_helper.dart`'s API có sẵn, đăng ký 1 `DeepLinkRoute` cho `invite` qua `DeepLinkCommandRouter.registerHandler` để nhận diện khi bạn mở link mời, lưu "đã dùng mã mời chưa" trong `StorageService` (1 `StorageKeys` mới).

**Giới hạn PHẢI ghi rõ trong code/doc comment** (đúng tinh thần honest-limitation của `ClampedClock`/`save_integrity.dart`): xác thực CHỈ ở mức best-effort LOCAL — không chống được tự-mời-chính-mình nếu không có server xác minh. Vì vậy coordinator KHÔNG tự phát thưởng — chỉ lo đúng phần "sinh mã + nhận diện mã đến từ deep link + đánh dấu đã dùng 1 lần", quyết định có thưởng gì hay không là trách nhiệm của app tiêu thụ (seam pattern, giống mọi service khác trong kit).

## Acceptance criteria
- [x] Sinh mã mời ổn định: cùng id người chơi → luôn ra cùng 1 mã qua nhiều lần gọi.
- [x] Nhận diện đúng mã mời từ 1 deep link `invite` hợp lệ qua `DeepLinkCommandRouter` thật (không phải parse URI thủ công riêng).
- [x] Đánh dấu "đã được mời" đúng 1 lần duy nhất — gọi lại lần 2 với mã khác không ghi đè/không tính thêm.
- [x] Test unit cho phần sinh mã (pure) + test widget/integration cho luồng nhận deep link thật qua router.

## Quyết định

**Implementation:**
- File mới `lib/core/invite_friend_coordinator.dart`: `InviteFriendCoordinator` — 1 lớp thuần (không phải `GetxService`, đúng convention `LeaderboardSyncCoordinator` đã dùng cho 1 "coordinator ghép nối hạ tầng có sẵn" — nhận dependency qua constructor, không tự singleton).
- `codeFor(String playerId) -> String`: hàm static thuần, `fnv1aHash(playerId).toRadixString(36).toUpperCase()` — không random, không I/O, cùng id luôn ra cùng mã (AC1), không cần lưu riêng vì tính lại được bất kỳ lúc nào từ id người chơi sẵn có.
- `InviteFriendCoordinator.route({required scheme, host = 'invite', commandType = 'invite'})`: factory tĩnh trả `DeepLinkRoute` khớp `<scheme>://invite?code=X` — app tiêu thụ phải tự đưa route này vào list `routes` khi khởi tạo `DeepLinkCommandRouter` (route KHÔNG thể thêm động sau khi router đã dựng — đã đọc kỹ `deep_link_command_router.dart` xác nhận đúng giới hạn này).
- Constructor `InviteFriendCoordinator({required router, required storage, commandType = 'invite'})`: gọi `router.registerHandler(commandType, _onInviteLink)` ngay trong constructor — TÁI DÙNG router/dispatch thật, không tự parse URI (AC2).
- `_onInviteLink`: nếu đã có `StorageKeys.inviteRedeemedCode` → bỏ qua ngay (không ghi đè, AC3); nếu chưa và `code` param không rỗng → `setString` 1 lần.
- `shareInvite(playerId, {sharePositionContext, messageBuilder})`: build message (mặc định hoặc tuỳ chỉnh) chứa `codeFor(playerId)`, gọi thẳng `shareText` có sẵn — không viết lại logic share.
- Thêm 1 `StorageKeys` mới: `inviteRedeemedCode`.
- **Giới hạn best-effort local đã ghi rõ trong doc comment của class** (đúng yêu cầu task): không chống tự-mời-chính-mình, không tự phát thưởng — chỉ lo đúng phần sinh mã + nhận diện + đánh dấu 1 lần, quyết định thưởng gì là của app tiêu thụ.
- Export mới trong `lib/roy_casual_kit.dart` (file `lib/core/` công khai, không phải widget qua barrel) → chạy `api_compatibility.dart check` ra "additive" → chạy `snapshot` → check lại ra "unchanged".

**TDD:** file lib mới hoàn toàn → di chuyển ra `/tmp` tạm thời → chạy 8 test mới → tất cả fail đúng lý do (`Method not found`/`Undefined name: InviteFriendCoordinator`, đúng vì class chưa tồn tại) → trả file lại → chạy lại pass.

**Kết quả:**
- `flutter analyze` (root): sạch.
- `dart run tool/api_compatibility.dart check`: `additive` (file+class mới) → `snapshot` → check lại: `unchanged`. Đã commit `tool/api_snapshot.json` cập nhật.
- `flutter test --exclude-tags slow` (root): 2341 test, 19 fail — đúng khớp baseline golden-image (macOS-vs-Linux) đã biết, không phát sinh flaky thêm, không có regression.
- Không đụng `example/` nên không cần chạy analyze/test ở đó.
- Không cần device smoke test (task cho phép bỏ qua — test đi qua `DeepLinkCommandRouter.handleUri` THẬT, không mock parser riêng, đủ chứng minh logic mà không cần link OS thật).

**Tự chấm điểm: 9.5/10.** Trừ 0.5 vì chưa có demo trong `example/` (task này chỉ yêu cầu lib + test, không yêu cầu demo screen — nằm ngoài phạm vi, tương tự IDEA-68/69 vừa làm).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-70-invite-friend-coordinator.md` này trước khi làm. Đọc toàn bộ `lib/core/utils/fnv1a.dart`, `lib/core/share_helper.dart`, `lib/core/deep_link_command_router.dart` (đặc biệt cách `DeepLinkRoute`/`registerHandler`/`DeepLinkCommand.params` hoạt động — path params VÀ query params được merge chung 1 map) trước khi thiết kế. Implement bằng TDD. Cân nhắc kỹ (ponytail) — không tự implement chống-gian-lận phức tạp, giới hạn best-effort local phải ghi rõ, không phát thưởng tự động.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit/widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (deep link test qua router thật đã đủ chứng minh logic, không cần link OS thật).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — đã tự Read xác nhận đúng API 3 mảnh (`fnv1aHash`, `DeepLinkRoute`/`DeepLinkCommandRouter.registerHandler`/`DeepLinkCommand`), ghép nối hợp lý. Effort M vì là feature mới hoàn toàn (không phải bug fix), cần cân nhắc kỹ thiết kế route/storage key trước khi code. Không trùng task nào trong `doc/task/done/` — 2 đợt audit trước đã cân nhắc và loại nhiều ý tưởng lớn khác (Gacha Kit, Battle Pass...) nhưng không thấy ý tưởng "invite friend" bị nhắc tới.
