---
id: ENH-19
title: "CloudSaveProvider là seam duy nhất thiếu accessor .maybe (khác CrashReporter/AnalyticsProvider)"
type: enhance
priority: exclusive (độ tin cậy thấp/marginal — xem ghi chú)
effort: S
source: Claude, audit round 3 (fork agent)
---

## Vị trí
`lib/core/cloud_save_provider.dart`:
```dart
abstract class CloudSaveProvider {
  Future<void> signIn();
  Future<void> upload(Map<String, Object?> data);
  Future<Map<String, Object?>?> download();
}
```
So với `lib/core/crash_reporter.dart` và `lib/core/analytics_provider.dart`
— cả 2 đều có thêm:
```dart
static X? get maybe => Get.isRegistered<X>() ? Get.find<X>() : null;
```

## Hiện trạng
3 "platform-neutral seam" (`CrashReporter`, `AnalyticsProvider`,
`CloudSaveProvider`) đều theo cùng 1 pattern tài liệu hoá kỹ (app tự
`Get.put` implementation của riêng họ) — nhưng `CloudSaveProvider` là
seam DUY NHẤT thiếu `.maybe`, không nhất quán API surface giữa 3 class
song song nhau.

## Ghi chú độ tin cậy
MARGINAL — khác với `CrashReporter`/`AnalyticsProvider` (được gọi từ nhiều
call site rải rác, cần null-safe lookup), cách dùng hiện tại của
`CloudSaveProvider` CHỈ có 1 điểm gọi trong toàn repo:
`VersionedJsonStore.syncWith(CloudSaveProvider provider)` — provider luôn
được TRUYỀN TRỰC TIẾP làm tham số, chưa từng được lookup qua `Get.find`
hay `Get.isRegistered` ở bất kỳ đâu. Vì vậy `.maybe` hiện KHÔNG có call
site nào cần dùng tới — thêm vào chỉ để "khớp pattern" chứ chưa giải quyết
nhu cầu thật nào đã phát sinh.

## Đề xuất
Chỉ thêm nếu xác nhận có kế hoạch cho 1 call site tự lookup
`CloudSaveProvider` qua Get thay vì luôn nhận tham số tường minh (ví dụ:
app muốn tự động `syncWith` mỗi lần resume mà không muốn truyền provider
lại mỗi lần). Nếu không có nhu cầu đó, đóng task này (YAGNI) — giữ nguyên,
đừng thêm code chết.

## Acceptance criteria
- [x] Xác nhận: có call site thật cần `.maybe` hay không.
- [ ] Nếu có: thêm `.maybe` theo đúng pattern `CrashReporter`/`AnalyticsProvider`, kèm test.
- [x] Nếu không: đóng task, ghi rõ lý do YAGNI trong `## Quyết định`.

## Quyết định
Đóng, YAGNI. Xác nhận lại bằng `grep -rn "CloudSaveProvider" lib/ example/
test/` — toàn bộ codebase chỉ có đúng 1 điểm dùng
(`VersionedJsonStore.syncWith(CloudSaveProvider provider)`, nhận tham số
trực tiếp) cộng bộ test riêng của `cloud_save_provider.dart`; không có
`Get.find`/`Get.isRegistered` nào cho class này ở bất kỳ đâu. Không thêm
`.maybe` cho nhu cầu chưa phát sinh.
