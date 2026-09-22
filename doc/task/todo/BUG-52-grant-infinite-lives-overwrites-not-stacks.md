---
id: BUG-52
title: "grantInfiniteLives() ghi đè thời điểm hết hạn thay vì cộng dồn — mua/nhận 2 lần liên tiếp mất phần thưởng lần trước"
type: bug
priority: P1
effort: XS
source: "agy (độc lập), verify lại qua Read lib/core/energy_service.dart (khu vực grantInfiniteLives)"
---

## Vị trí
`lib/core/energy_service.dart` — `grantInfiniteLives(Duration duration)`.

## Hiện trạng
```dart
Future<void> grantInfiniteLives(Duration duration) => StorageService.to.setInt(
  StorageKeys.energyInfiniteUntilMs,
  nowMsClamped() + duration.inMilliseconds,
);
```
Luôn ghi `nowMsClamped() + duration` — không so sánh với giá trị `energyInfiniteUntilMs` hiện có trước đó.

## Vì sao cần / Hậu quả
Người chơi mua/nhận 2 gói "năng lượng vô hạn 1 giờ" liên tiếp (ví dụ IAP + phần thưởng event trùng thời điểm) — lần thứ 2 GHI ĐÈ lên lần thứ nhất thay vì cộng dồn thời gian, người chơi mất trắng phần thưởng vừa nhận lần đầu nếu lần 2 grant với duration ngắn hơn thời gian còn lại của lần 1 (hoặc chỉ nhận đúng 1 lần dù đã trả tiền/đổi thưởng 2 lần).

## Đề xuất
So sánh với giá trị hiện có, lấy `max` giữa mốc mới và mốc cũ:
```dart
Future<void> grantInfiniteLives(Duration duration) {
  final current = StorageService.to.getInt(StorageKeys.energyInfiniteUntilMs, def: 0);
  final next = nowMsClamped() + duration.inMilliseconds;
  return StorageService.to.setInt(StorageKeys.energyInfiniteUntilMs, current > next ? current : next);
}
```

## Acceptance criteria
- [ ] Gọi `grantInfiniteLives` 2 lần liên tiếp (lần 2 có duration ngắn hơn thời gian còn lại của lần 1) — mốc hết hạn GIỮ giá trị lớn hơn (không bị rút ngắn).
- [ ] Gọi `grantInfiniteLives` khi chưa có mốc nào trước đó — hoạt động đúng như cũ.
- [ ] Test hiện có của `energy_service_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-52-grant-infinite-lives-overwrites-not-stacks.md` này trước khi làm. Đọc toàn bộ `lib/core/energy_service.dart` và test hiện có trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix nhỏ, unit test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — tự Read trực tiếp code, xác nhận đúng như mô tả (không có so sánh `max` với giá trị cũ). Không trùng task nào trong `doc/task/done/`.
