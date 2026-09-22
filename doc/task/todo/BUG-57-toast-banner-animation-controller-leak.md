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
- [ ] `entry` unmounted trước khi `remove()` được gọi — `controller.dispose()` vẫn được gọi (verify qua test kiểm tra controller đã dispose, không throw "used after dispose" ở lần gọi kế tiếp).
- [ ] Trường hợp bình thường (entry vẫn mounted) hành vi animate-reverse-rồi-đóng không đổi.
- [ ] Test hiện có của `toast_banner_test.dart` vẫn pass.

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
