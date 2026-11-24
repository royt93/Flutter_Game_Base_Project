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

- [x] 1. Đọc `retry_policy.dart`, `offline_outbox_service.dart`, `connectivity_coordinator.dart`, `cloud_save_provider.dart`; ghi bảng kịch bản (thành phần × điều kiện mạng) vào "Kết quả thực hiện", đánh dấu ô đã có test.
- [x] 2. Viết `test/support/conditioned_providers.dart` (fake có điều khiển, dùng `fake_async`/`FakeAsync` đã có sẵn trong `flutter_test`, không thêm gói).
- [x] 3. Test các ô thiếu: sync fail 2 lần rồi ok (kết quả `SdkSuccess`, không ghi đè local khi fail), timeout giữa upload (local không mất), payload hỏng (BUG-141/142 giữ), offline→online xả hàng đợi đúng thứ tự và không trùng, backoff đúng lịch.
- [x] 4. Mutation check từng test (phá logic retry/ghi đè, test phải đỏ).
- [x] 5. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Mọi ô thành phần × điều kiện mạng có test hoặc lý do loại.
- [x] Không test nào ngủ thật (dùng `FakeAsync`).
- [x] Lỗi tìm thấy tạo task BUG riêng.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/offline_outbox_service_test.dart test/core/connectivity_coordinator_test.dart test/core/versioned_json_store_test.dart`

## Kết quả thực hiện (2026-11-24)

### Ma trận thành phần x điều kiện mạng

Cột "Trước" là test đã có; "Sau" là `test/core/network_conditions_test.dart` (20 test). Fake dùng chung: `test/support/conditioned_providers.dart` (`NetworkScript` với `ok`/`fail`/`hang`/`slow`, `ConditionedCloudSaveProvider`, `ConditionedOutboxUploader`), không phải API công khai.

| Thành phần | Điều kiện | Trước | Sau |
| --- | --- | --- | --- |
| `VersionedJsonStore.syncWithResult` | download rớt | có (BUG-84, một ca) | + local không đổi, không upload |
| | upload rớt rồi sync lại thành công | thiếu | có |
| | chập chờn fail, fail, ok: một upload duy nhất | thiếu | có |
| | cloud mới hơn chỉ thắng ở lần sync sau khi download từng rớt | thiếu | có |
| | cloud CŨ hơn không ghi đè local mới hơn sau khi download rớt | thiếu | có |
| | upload chậm: local đã an toàn trong lúc upload chưa xong | thiếu | có |
| | payload cloud hỏng sau một lần rớt | có (BUG-141/142, không kèm rớt) | + kèm rớt |
| | download treo vô hạn | thiếu | có: sync KHÔNG có timeout riêng, caller phải đặt |
| `OfflineOutboxService` | fail hai lần rồi ok trong một drain, lịch backoff | thiếu | có (200ms rồi 400ms, không chờ trước lần đầu) |
| | hết retry: item còn, drain sau giao được | có | + giao được ở drain sau |
| | item đầu hỏng không chặn item độc lập sau | thiếu | có |
| | upload treo: không ack, không mất item | thiếu | có |
| | timeout theo lần thử là TERMINAL (BUG-96), không thử lần hai | có (ở `RetryExecutor`) | + ở outbox |
| | offline rồi online: xả đúng thứ tự ưu tiên, một lần | có (một ca) | + ba mức ưu tiên |
| | chập chờn kết nối: mỗi lần online xả lại, không trùng | thiếu | có |
| | khởi động lại khi offline, xả khi có mạng | có | + qua fake dùng chung |
| `RetryExecutor` | lịch backoff theo N lần lỗi, bị chặn ở `maxDelay` | có (công thức) | + qua executor, jitter và cap |
| | độ trễ là cổng chờ, không ngủ thật | thiếu | có |
| `ConnectivityCoordinator` | flap, probe lỗi, degraded, offline | có đủ (`connectivity_coordinator_test`) | giữ nguyên |
| `PrivacyAwareAnalyticsQueue`, `AchievementSyncSeam`, `LeaderboardSyncSeam` | | có test riêng; KHÔNG chạy lại dưới fake chung | loại: cùng `RetryExecutor`, đã được phủ ở trên |

### Số liệu

- 20 test mới, tất cả xanh. Cổng cuối: analyze sạch; `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation` 4216 pass (trước 4196, +20); `api_compatibility` unchanged; 5 quality-gate sạch.
- Không thêm gói (đề bài nhắc `FakeAsync` nhưng `flutter_test` không xuất `fakeAsync`; dùng `testWidgets` + `tester.pump(Duration)` làm đồng hồ giả, kết quả cùng bản chất: không test nào ngủ thật).
- Mutation (10 biến đổi lib N1-N10, cả 10 bị bắt; N3, N4 và N9 phải chạy lại sau khi thêm test hoặc sửa pattern): download ném lại thay vì `SdkFailure` (3 test đỏ), upload lỗi bị nuốt thành thành công (2), cloud luôn thắng không so timestamp (1), outbox xoá item khi hết retry (4), dừng drain sau item lỗi đầu (1), đảo thứ tự ưu tiên (2), timeout được retry lại (1), backoff không nhân đôi (2), backoff không bị chặn `maxDelay` (1), sự kiện online không xả (2). Lib khôi phục (`cmp` giống hệt).
- Hai mutant sống sót ban đầu (N3, N9) buộc thêm test, và N4 bị bỏ sót do pattern sai: "cloud cũ không ghi đè local mới hơn" (N3: cloud luôn thắng), "backoff có jitter vẫn bị chặn `maxDelay`" (N9: bỏ `min` không đổi kết quả khi không jitter vì `clamp` ở bước sau cũng chặn; chỉ khi jitter kéo delay xuống mới lộ), và N4 chạy lại với pattern đúng (comment nằm giữa mã) rồi bị bắt.

### Phát hiện (không phải bug)

- `syncWithResult` KHÔNG có timeout riêng: download treo thì không bao giờ trả về, local không bị hỏng. Đây là hành vi đúng của seam (caller đặt timeout bằng `RetryPolicy.timeout` hoặc `Future.timeout`), nhưng chưa được ghi trong dartdoc; test khoá hành vi này. Nếu muốn doc rõ: thuộc ENH-129 (dartdoc).
- Không có bug lib mới, không tạo task BUG.

### Hạn chế

- Đây là fake có điều khiển, không phải mạng thật: không chứng minh hành vi trên đường truyền thực (DNS, TLS, mất gói một phần, đổi Wi-Fi sang 4G).
- `ConnectivityCoordinator` tự chạy probe theo `Timer`: test dùng timer `Duration.zero` như test cũ, không dùng đồng hồ giả cho khoảng 15 giây của `probeInterval`.
