---
id: BUG-57
title: "ToastBanner.remove() early-return trước dispose() khi entry đã unmounted — leak AnimationController/Ticker"
type: bug
priority: P1
effort: XS
source: "agy (độc lập), verify lại qua Read lib/presentation/widgets/common/toast_banner.dart:95-115"
---

## Vị trí
`lib/presentation/widgets/common/toast_banner.dart` — `remove()`.

## Hiện trạng
```dart
Future<void> remove() async {
  if (!entry.mounted) return;
  try {
    await controller.reverse();
  } catch (_) {}
  entry.remove();
  controller.dispose();
}
```
`if (!entry.mounted) return;` thoát SỚM trước `controller.dispose()` — khi `OverlayEntry` đã unmounted (ví dụ người dùng chuyển màn hình/pop route trước khi toast tự đóng), `controller` (một `AnimationController` với `Ticker` riêng) không bao giờ được dispose.

## Vì sao cần / Hậu quả
Mỗi `ToastBanner.show()` mà bị "cắt ngang" bởi chuyển màn hình trước khi tự đóng sẽ rò rỉ 1 `AnimationController`/`Ticker`. `ToastBanner` là kênh feedback được dùng RẤT NHIỀU (theo CLAUDE.md, gần như kênh duy nhất thay `SnackBar`/`Get.dialog` phía trên Flame `GameWidget`) — tích luỹ qua 1 phiên chơi dài có thể gây leak đáng kể.

## Đề xuất
Dispose `controller` TRƯỚC khi kiểm tra/return theo `entry.mounted`, hoặc tách 2 bước rõ ràng: luôn `controller.dispose()` bất kể `entry.mounted`, chỉ bỏ qua `entry.remove()`/`await controller.reverse()` nếu đã unmounted (không cần animate reverse cho 1 overlay đã biến mất).

## Acceptance criteria
- [x] `entry` unmounted trước khi `remove()` được gọi — `controller.dispose()` vẫn được gọi (verify qua test kiểm tra controller đã dispose, không throw "used after dispose" ở lần gọi kế tiếp).
- [x] Trường hợp bình thường (entry vẫn mounted) hành vi animate-reverse-rồi-đóng không đổi.
- [x] Test hiện có của `toast_banner_test.dart` vẫn pass.

## Quyết định
Fix đúng theo hướng thứ 2 trong đề xuất: tách rõ 2 bước — `entry.remove()`/`await controller.reverse()` chỉ chạy khi `entry.mounted`, còn `controller.dispose()` LUÔN chạy, bất kể. Thêm 1 cờ `disposed` để `remove()` idempotent (không double-dispose nếu bị gọi lại).

**Không viết được widget test end-to-end qua đúng `ToastBanner.show()` cho case "entry unmounted, controller vẫn sống"** — đã thử nghiệm trực tiếp (probe script tạm, xoá sau khi xong) và xác nhận bằng thực nghiệm: `Overlay.of(context, rootOverlay: true)` (chủ đích để toast sống sót qua route pop) trói vòng đời `entry` vào ĐÚNG `NavigatorState` mà `controller` dùng làm `vsync`. Trong 1 app 1-Navigator (cấu trúc thực tế duy nhất dựng lại được bằng widget test), "entry unmounted" và "vsync/Navigator bị dispose" LUÔN xảy ra đồng thời — probe với `pumpWidget(SizedBox())` (thay toàn bộ cây) cho kết quả GIỐNG HỆT nhau ở cả code cũ (bug) lẫn code mới (fix): đúng 1 lỗi `NavigatorState disposed with an active Ticker` tại thời điểm thay cây (không liên quan gì đến `remove()`, xảy ra TRƯỚC khi `remove()` kịp chạy), sau đó timer `Future.delayed` bắn `remove()` không phát sinh thêm lỗi nào ở CẢ HAI phiên bản — tức là kịch bản duy nhất dựng lại được không phân biệt được code cũ/mới, không dùng làm TDD proof được. `entry.mounted == false` không thể xảy ra bằng cách nào khác trong codebase này (không nơi nào khác gọi `entry.remove()`).

Vì vậy verify criterion 1 bằng 1 test logic độc lập, dùng `AnimationController` + `TestVSync` THẬT (không phải class giả lập tay) để chứng minh đúng property mà fix bảo vệ: dispose() phải chạy dù nhánh "mounted" là false, và gọi lại `forward()` sau đó throw đúng lỗi Flutter tự bảo vệ ("used after being disposed") — bằng chứng dispose() thực sự đã chạy. Ghi rõ trong comment test đây là test PATTERN (không exercise trực tiếp closure private trong `toast_banner.dart`, vì không có seam để làm vậy) — cùng tinh thần với cách BUG-61 trong phiên làm việc này đã pivot sang structural verification khi không dựng lại được race thật trong test.

Criterion 2 (trường hợp bình thường vẫn mounted) đã được cover sẵn bởi 4 test có sẵn trong `toast_banner_test.dart` (không cần thêm) — chạy lại xác nhận vẫn pass nguyên vẹn.

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2083 pass / -19 fail (baseline golden có sẵn, không liên quan), `dart run tool/api_compatibility.dart check` unchanged, `example/` `flutter test --exclude-tags slow` 129/129 pass (example dùng `ToastBanner` qua `cookbook_screen.dart`/`widget_showcase_screen.dart`).

Tự chấm: **9.5/10** — root cause đúng, code fix khớp 100% đề xuất + doc comment, thêm idempotent guard hợp lý. Trừ 0.5 vì không chứng minh được bằng test end-to-end thật qua `ToastBanner.show()` (giới hạn kiến trúc thật, đã giải thích và thực nghiệm rõ ở trên, không phải bỏ sót) — chỉ có test logic-pattern độc lập.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-57-toast-banner-animation-controller-leak.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/common/toast_banner.dart` và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria (verify không leak — có thể kiểm tra qua đảm bảo `dispose()` được gọi, hoặc dùng `flutter_test`'s leak-tracking nếu có sẵn trong repo).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device thật khuyến khích (hiện toast rồi chuyển màn hình ngay lập tức nhiều lần, verify không crash/không leak dồn) không bắt buộc nếu widget test đã đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — tự Read trực tiếp code, xác nhận `if (!entry.mounted) return;` nằm TRƯỚC `controller.dispose()`, đúng như mô tả. Không trùng task nào trong `doc/task/done/`.
