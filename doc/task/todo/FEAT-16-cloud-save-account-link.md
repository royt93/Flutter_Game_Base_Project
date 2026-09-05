---
id: FEAT-16
title: Cloud save / account linking (Google Play Games, Game Center, hoặc Firebase anonymous auth)
type: feature
priority: P0
effort: L
verified: true
source: Claude, phát hiện khi audit bổ sung (grep xác nhận toàn bộ persistence chỉ SharedPreferences local)
---

## Vấn đề
Toàn bộ `StorageService` hiện chỉ wrap `SharedPreferences` — dữ liệu 100%
local trên máy. Người chơi đổi máy, cài lại app, hoặc xoá app đều mất sạch
tiến trình (tiền, level, achievement...). Đây là gap lớn nhất còn lại của
package: mọi hệ thống reward khác (FEAT-05..09) đều vô nghĩa nếu dữ liệu có
thể mất bất cứ lúc nào.

## Đề xuất phạm vi (MVP cho 1 base kit)
1 interface trung lập (không kéo cứng Firebase vào package gốc, theo đúng
pattern `AnalyticsProvider`/`CrashReporter`):
```dart
abstract class CloudSaveProvider {
  Future<void> signIn();
  Future<void> upload(Map<String, Object?> data);
  Future<Map<String, Object?>?> download();
}
```
App tự implement adapter cắm Google Play Games Services / Game Center /
Firebase Auth + Firestore vào interface này. `StorageService` có thể thêm 1
hàm `syncWith(CloudSaveProvider)` đơn giản (upload khi thay đổi, download lúc
mở app + merge theo timestamp mới nhất — conflict resolution tối giản, không
cần merge 3-way).

## Acceptance criteria
- [ ] Interface tồn tại trong `lib/core/`, có fake implementation trong test.
- [ ] `StorageService` có 1 điểm nối (`syncWith`) chứng minh interface dùng được, không bắt buộc app phải cắm ngay.

## Ghi chú ưu tiên
Đề xuất làm SAU khi có FEAT-05 (save-slot versioning) — cloud save nên đồng bộ
đúng 1 object đã versioned, không đồng bộ key-value rời rạc.
