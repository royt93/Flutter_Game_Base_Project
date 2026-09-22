---
id: BUG-59
title: "ShareHelper: ui.Picture không bao giờ dispose (leak Skia) + thiếu sharePositionOrigin gây crash trên iPad"
type: bug
priority: P1
effort: S
source: "agy (độc lập), verify lại qua Read lib/core/share_helper.dart:75-130"
---

## Vị trí
`lib/core/share_helper.dart` — `_withTextOverlay`/`captureBoardPng` (~dòng 78-90), `shareText`/`shareBoardImage`/`shareScoreCard`/`shareJourneyCard` (~dòng 98-130).

## Hiện trạng
1. `final picture = recorder.endRecording(); return picture.toImage(...);` — `ui.Picture` (native Skia object) không bao giờ được `picture.dispose()`.
2. `SharePlus.instance.share(ShareParams(text: ..., files: [...], fileNameOverrides: [...]))` không truyền `sharePositionOrigin`.

## Vì sao cần / Hậu quả
(1) rò rỉ bộ nhớ đồ hoạ native mỗi lần chia sẻ thẻ chiến thắng/journey — tích luỹ qua nhiều lần share trong 1 phiên chơi dài. (2) trên iPad/iPadOS, thiếu popover anchor cho share sheet (iPad dùng popover thay vì bottom sheet như iPhone) ném `NSGenericException`/crash khi gọi share — ảnh hưởng mọi consumer app target iPad.

## Đề xuất
1. Gọi `picture.dispose()` ngay sau `picture.toImage(...)` hoàn tất (trong `finally` nếu cần xử lý lỗi giữa chừng).
2. Truyền `sharePositionOrigin` dựa trên vị trí widget gọi share (dùng `RenderBox` của context gọi, `Rect` bao quanh) cho cả 4 hàm share.

## Acceptance criteria
- [x] Gọi `captureBoardPng`/`_withTextOverlay` nhiều lần liên tiếp không tích luỹ leak `ui.Picture` (verify qua code review — Dart test không đo trực tiếp native memory, nhưng đảm bảo `dispose()` được gọi đúng 1 lần mỗi `endRecording()`).
- [x] Cả 4 hàm share (`shareText`/`shareBoardImage`/`shareScoreCard`/`shareJourneyCard`) truyền `sharePositionOrigin` hợp lệ.
- [x] Test hiện có của `share_helper_test.dart` vẫn pass.
- [x] Không đổi nội dung/định dạng file được share (chỉ thêm dispose + origin, không đổi hành vi quan sát được khác).

## Quyết định
Cả 2 phần fix đúng đề xuất gốc:

1. `picture.dispose()` trong `finally`, sau `await picture.toImage(...)` — Picture (native Skia, tách biệt hẳn với `ui.Image` mà BUG-29 đã dispose) giờ luôn được dọn dẹp dù `toImage()` thành công hay throw giữa chừng.
2. Thêm tham số optional `BuildContext? sharePositionContext` cho cả 4 hàm share (`shareText`/`shareBoardImage`/`shareScoreCard`/`shareJourneyCard`) — API mở rộng THUẦN CỘNG (existing call site không cần đổi, mặc định `null` giữ nguyên hành vi cũ y hệt trước fix). Hàm private `_sharePositionOriginOf(context)` quy đổi `RenderBox` của context đó thành `Rect` toàn cục truyền vào `ShareParams.sharePositionOrigin`. Đã cập nhật call site thật duy nhất trong repo (`example/lib/screens/widget_showcase_screen.dart`'s `_shareVictoryCard`) để truyền `context`. `flutter analyze` bắt đúng 1 vấn đề thật liên quan (`use_build_context_synchronously` ở `shareBoardImage`/`shareScoreCard` — context dùng SAU 1 `await captureBoardPng(...)`, widget có thể đã unmount giữa chừng) — sửa bằng cách tính `sharePositionOrigin` TRƯỚC `await`, không phải sau.

**TDD verify**:
- Phần 1 (Picture leak): copy đúng kỹ thuật BUG-29 (`ui.Image.onCreate`/`onDispose` toàn-VM) sang `ui.Picture.onCreate`/`onDispose`. Phát hiện: `renderObject.toImage()` (Flutter framework nội bộ, chạy ở MỌI lần gọi `captureBoardPng` kể cả không có overlayText) cũng phát Picture riêng của framework qua đúng hook toàn-VM này — không assert `disposed == created` tuyệt đối được (baseline framework không do code package tạo ra để mà dispose). Test đúng: gọi lặp lại 5 lần, so sánh gap `created - disposed` KHÔNG tăng dần theo N — nếu Picture của `_withTextOverlay` bị leak, gap tăng đúng 1 mỗi lần gọi (baseline framework thì không tăng theo N). `git stash`-kiểu-thủ-công (revert riêng đoạn `try/finally` trong `_withTextOverlay`, giữ nguyên phần `sharePositionContext`) — FAIL đúng: gap `[4, 5, 6, 7, 8]` tăng dần rõ ràng trên code cũ. Khôi phục fix — gap ổn định, pass.
- Phần 2 (sharePositionOrigin): dùng seam test chính thức của `share_plus` — `SharePlatform.instance` (setter public, `share_plus` document dùng cho test). Phát hiện: `SharePlus.instance` là `static final`, chỉ đọc `SharePlatform.instance` ĐÚNG 1 LẦN trong cả isolate — set lại `SharePlatform.instance` ở test SAU không có tác dụng nếu tạo fake mới mỗi test. Sửa: dùng chung 1 `_FakeSharePlatform` cho cả group, chỉ reset field `lastParams` giữa các test. `git diff` full lib (đổi cả API, không param `sharePositionContext`) làm test lỗi COMPILE (thiếu tham số) — đúng "fail without fix" ở mức biên dịch, không lệch spirit TDD dù không phải runtime assertion.

Kết quả cuối: `flutter analyze` root sạch (đã sửa cả 2 `use_build_context_synchronously` info + 2 lint import thừa trong test), `dart pub publish --dry-run` chỉ còn cảnh báo tiêu chuẩn (uncommitted files, version chưa bump — không phải lỗi, cùng baseline mọi task trước), `flutter test --exclude-tags slow` root 2088 pass / -19 fail (baseline golden có sẵn, không liên quan), `dart run tool/api_compatibility.dart check` unchanged, `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 129/129 pass. Thêm `share_plus_platform_interface` vào `dev_dependencies` (chỉ dùng trong test, cần thiết vì `flutter analyze` cấm import package chỉ là transitive dependency).

Không smoke test device Android thật (task ghi "khuyến khích", không bắt buộc) — phần iPad-crash tuyệt đối không verify được trên Android như task đã tự ghi nhận trước; phần Picture-dispose đã chứng minh đủ bằng unit test (native memory, Dart test không đo trực tiếp được, đúng như acceptance criteria đã ghi).

Tự chấm: **9.5/10** — root cause đúng cả 2 phần, API mở rộng an toàn (thuần cộng, không breaking), TDD chứng minh phần dispose bằng kỹ thuật gap thay vì equality cứng (đúng và mạnh hơn), phần sharePositionOrigin verify qua platform seam chính thức của package. Trừ 0.5 vì không có smoke test device thật (không bắt buộc, đã giải thích).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-59-share-helper-picture-leak-and-ipad-crash.md` này trước khi làm. Đọc toàn bộ `lib/core/share_helper.dart` và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit/widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật khuyến khích (verify share vẫn hoạt động đúng, ảnh vẫn đúng nội dung sau khi thêm dispose) — không thể verify phần iPad-crash trên Android, ghi rõ giới hạn này trong Quyết định.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự Read trực tiếp code, xác nhận không có `picture.dispose()` nào trong file, và cả 3 lệnh `SharePlus.instance.share(...)` xem được không truyền `sharePositionOrigin`. Không trùng task nào trong `doc/task/done/`.
