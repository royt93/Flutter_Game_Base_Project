---
id: FEAT-03
title: Analytics/event tracking interface trung lập
type: feature
priority: P0
effort: M
source: fork nội bộ
---

## Vì sao cần
Mọi game cần track funnel (level start/complete/fail, purchase, retention).
Package hiện chưa có bất kỳ hook nào cho việc này.

## Đề xuất phạm vi
1 interface đơn giản, không ràng buộc SDK cụ thể:
```dart
abstract class AnalyticsProvider {
  void logEvent(String name, [Map<String, Object?>? params]);
}
```
Kèm 1 `NoopAnalyticsProvider` mặc định (không làm gì) để app không bắt buộc
phải cắm ngay từ đầu, và 1 `AnalyticsProvider.maybe`-style accessor theo đúng
pattern `AudioManager.maybe` đã có trong codebase.

## Acceptance criteria
- [ ] Interface + noop implementation tồn tại trong `lib/core/`.
- [ ] Test xác nhận `NoopAnalyticsProvider` không throw khi gọi `logEvent`.
