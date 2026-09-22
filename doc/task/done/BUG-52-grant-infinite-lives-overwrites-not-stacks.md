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
- [x] Gọi `grantInfiniteLives` 2 lần liên tiếp (lần 2 có duration ngắn hơn thời gian còn lại của lần 1) — mốc hết hạn GIỮ giá trị lớn hơn (không bị rút ngắn).
- [x] Gọi `grantInfiniteLives` khi chưa có mốc nào trước đó — hoạt động đúng như cũ.
- [x] Test hiện có của `energy_service_test.dart` vẫn pass.

## Quyết định
Fix đúng như đề xuất trong task (dùng `max` giữa mốc cũ và mốc mới). Không lệch scope.

TDD verify: `git stash` riêng `lib/core/energy_service.dart`, chạy 3 test mới — test "duration ngắn hơn KHÔNG rút ngắn mốc" FAIL đúng trên code cũ (`Expected: 1790084433870 (mốc dài từ lần 1), Actual: 1790081133871 (bị ghi đè bởi mốc ngắn của lần 2)`); 2 test còn lại (duration dài hơn, grant lần đầu) đã pass sẵn trên code cũ vì không chạm đúng nhánh lỗi (case ghi đè chỉ lộ khi mốc mới NHỎ HƠN mốc cũ) — đúng bản chất bug chỉ biểu hiện ở 1 trong 3 case, không phải test yếu. `git stash pop`, chạy lại toàn file — 28/28 pass.

Kết quả cuối: `flutter analyze` root sạch, `flutter test --exclude-tags slow` root 2077 pass (baseline -19 golden có sẵn; lần chạy có thêm 1 fail `neon_back_button_test.dart` không liên quan — chạy riêng file đó pass 2/2, xác nhận flake nhất thời, không phải do fix này), `dart run tool/api_compatibility.dart check` unchanged, `example/` `flutter test --exclude-tags slow` 129/129 pass.

Tự chấm: **9.5/10** — 1 hàm, root cause đúng, khớp 100% đề xuất đã verify sẵn, TDD chứng minh case lỗi thật, không phá test cũ.

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
