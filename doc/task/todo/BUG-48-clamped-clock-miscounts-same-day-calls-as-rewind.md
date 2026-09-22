---
id: BUG-48
title: "todayEpochDayClamped() tăng clockRewindBlockedCount ở MỌI lần gọi cùng ngày, không chỉ khi thật sự tua lùi giờ"
type: bug
priority: P1
effort: XS
source: "agy (độc lập), verify lại qua Read lib/core/utils/clamped_clock.dart:45-65"
---

## Vị trí
`lib/core/utils/clamped_clock.dart` — `todayEpochDayClamped()` (~dòng 52-61).

## Hiện trạng
```dart
int todayEpochDayClamped() {
  final current = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
  final maxSeen = StorageService.to.getInt(StorageKeys.maxEpochDaySeen);
  if (current > maxSeen) {
    StorageService.to.setInt(StorageKeys.maxEpochDaySeen, current);
    return current;
  }
  clockRewindBlockedCount++;
  return maxSeen;
}
```
Trong suốt 1 ngày, `current == maxSeen` sau lần gọi đầu tiên — điều kiện `current > maxSeen` false, rơi vào nhánh `else` tăng `clockRewindBlockedCount++` dù KHÔNG có rewind nào xảy ra (chỉ đơn giản là gọi lại hàm trong cùng ngày, hoàn toàn bình thường).

## Vì sao cần / Hậu quả
Người chơi mở app nhiều lần/chuyển màn hình khiến hàm này được gọi lại nhiều lần trong ngày sẽ tích lũy hàng chục/hàng trăm "lần chặn rewind" giả — làm sai lệch hoàn toàn số liệu QA/analytics chống gian lận (không thể phân biệt được người chơi bình thường với người chơi thật sự đang tua giờ).

## Đề xuất
Chỉ tăng `clockRewindBlockedCount` khi `current < maxSeen` (rewind thật). Khi `current == maxSeen`, trả về `maxSeen` bình thường không tăng counter:
```dart
if (current > maxSeen) {
  StorageService.to.setInt(StorageKeys.maxEpochDaySeen, current);
  return current;
}
if (current < maxSeen) clockRewindBlockedCount++;
return maxSeen;
```

## Acceptance criteria
- [ ] Gọi `todayEpochDayClamped()` nhiều lần trong CÙNG 1 ngày (current == maxSeen mọi lần) — `clockRewindBlockedCount` không đổi.
- [ ] Rewind thật (current < maxSeen) vẫn tăng đúng `clockRewindBlockedCount` như cũ.
- [ ] Ngày mới thật (current > maxSeen) vẫn cập nhật `maxEpochDaySeen` và trả về `current` đúng như cũ.
- [ ] Test hiện có trong `test/core/utils/clamped_clock_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-48-clamped-clock-miscounts-same-day-calls-as-rewind.md` này trước khi làm. Đọc toàn bộ `lib/core/utils/clamped_clock.dart` và `test/core/utils/clamped_clock_test.dart` trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix 1 dòng logic, unit test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — tự Read trực tiếp code, logic sai hiển nhiên và dễ verify (so sánh `>` thay vì phân biệt `==`/`<`). Không trùng task nào trong `doc/task/done/`.
