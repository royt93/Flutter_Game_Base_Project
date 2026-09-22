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
- [ ] Gọi `captureBoardPng`/`_withTextOverlay` nhiều lần liên tiếp không tích luỹ leak `ui.Picture` (verify qua code review — Dart test không đo trực tiếp native memory, nhưng đảm bảo `dispose()` được gọi đúng 1 lần mỗi `endRecording()`).
- [ ] Cả 4 hàm share (`shareText`/`shareBoardImage`/`shareScoreCard`/`shareJourneyCard`) truyền `sharePositionOrigin` hợp lệ.
- [ ] Test hiện có của `share_helper_test.dart` vẫn pass.
- [ ] Không đổi nội dung/định dạng file được share (chỉ thêm dispose + origin, không đổi hành vi quan sát được khác).

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
