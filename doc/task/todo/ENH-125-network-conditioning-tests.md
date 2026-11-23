---
id: ENH-125
title: "Network conditioning test: trễ, rớt gói, timeout, chập chờn (fail N lần rồi thành công), offline→online"
type: enhancement
layer: test/core
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- Kit không có mã mạng riêng; tầng mạng là các seam: `CloudSaveProvider`, `AchievementSyncSeam`, `LeaderboardSyncSeam`, `OfflineOutboxService`, `ConnectivityCoordinator`, `retry_policy`, `PrivacyAwareAnalyticsQueue`. Nên "network conditioning" ở đây là điều kiện hoá nhà cung cấp GIẢ, không phải giả lập mạng thật.
- Đã có: `connectivity_coordinator_test.dart`, `offline_outbox_service_test.dart` (14 mục có throw/Timeout), `versioned_json_store_test.dart` (provider ném khi download/upload), `analytics` ACK demo. `cloud_save_provider_test.dart` đếm 0 mục lỗi (grep `Timeout|SocketException|throw`).
- Chưa có: một nhà cung cấp giả CÓ ĐIỀU KHIỂN dùng chung (độ trễ, tỉ lệ rớt, fail N lần rồi thành công, timeout), nên mỗi test tự dựng fake riêng.

## Phạm vi

Thêm một fake dùng chung trong `test/support/` (không phải API công khai): `ConditionedCloudSaveProvider` với chế độ trễ (dùng `FakeAsync`, không ngủ thật), rớt, timeout, fail-N-rồi-ok, trả payload hỏng. Dùng nó chạy lại các kịch bản cho `VersionedJsonStore.syncWithResult`, `OfflineOutboxService`, `retry_policy`.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc `retry_policy.dart`, `offline_outbox_service.dart`, `connectivity_coordinator.dart`, `cloud_save_provider.dart`; ghi bảng kịch bản (thành phần × điều kiện mạng) vào "Kết quả thực hiện", đánh dấu ô đã có test.
- [ ] 2. Viết `test/support/conditioned_providers.dart` (fake có điều khiển, dùng `fake_async`/`FakeAsync` đã có sẵn trong `flutter_test`, không thêm gói).
- [ ] 3. Test các ô thiếu: sync fail 2 lần rồi ok (kết quả `SdkSuccess`, không ghi đè local khi fail), timeout giữa upload (local không mất), payload hỏng (BUG-141/142 giữ), offline→online xả hàng đợi đúng thứ tự và không trùng, backoff đúng lịch.
- [ ] 4. Mutation check từng test (phá logic retry/ghi đè, test phải đỏ).
- [ ] 5. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Mọi ô thành phần × điều kiện mạng có test hoặc lý do loại.
- [ ] Không test nào ngủ thật (dùng `FakeAsync`).
- [ ] Lỗi tìm thấy tạo task BUG riêng.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/offline_outbox_service_test.dart test/core/connectivity_coordinator_test.dart test/core/versioned_json_store_test.dart`
