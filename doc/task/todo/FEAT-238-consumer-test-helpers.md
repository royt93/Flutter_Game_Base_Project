---
id: FEAT-238
title: "Mở rộng test kit cho consumer: đồng hồ giả, helper dựng widget kit, fake PurchaseSeam/CloudSaveProvider có điều khiển"
type: feature
layer: lib/core + doc
priority: P3
effort: M
source: "Đề xuất của Claude 2026-11-24 (dev-experience SDK), owner chọn đưa vào backlog"
---

## Hiện trạng đã kiểm

- `lib/core/consumer_contract_test_kit.dart` có `RoyCasualKitTestFixture` (storage trong bộ nhớ, `config` cho `RoyCasualKit.initialize`) và `RoyCasualKitContractTestKit.verifyBootstrap` (báo cáo thuần Dart `RoyCasualKitContractReport`). README (dòng ~871) và INTEGRATION_GUIDE nhắc tới; `example/test/cookbook_screen_test.dart` dùng.
- `PluginAdapterConformanceSuite` đã có `FakePurchaseSeam` (và `verifyPurchaseSeam`) cho kiểm hợp đồng adapter.
- Những mẫu tôi phải tự viết lại nhiều lần khi test kit: `ownedStorage`/`ownedMemoryStorage` (`test/support/owned_storage.dart`, đóng `StorageService` cuối test), `_GatedStorageService` (giữ một lượt ghi giữa chừng, trong `season_event_service_test`), `setDebugTimeOffsetMs` kèm `tearDown` đặt lại 0 (`utc_day_boundary_test`), dựng `MaterialApp` + `AppTranslations`. Consumer sẽ phải tự viết lại tương tự.

## Ranh giới cần chốt TRƯỚC khi code

Cái gì vào `lib/` (thành API công khai phải duy trì, qua snapshot gate) và cái gì chỉ là ví dụ/tài liệu hoặc nằm ở `test/support` của kit (không xuất bản). Đề xuất: chỉ đưa vào `lib/` thứ không cần `flutter_test` (đồng hồ giả, fake seam); helper dựng widget cần `flutter_test` (dev dependency) thì KHÔNG đưa vào `lib/` mà ghi thành đoạn mẫu trong INTEGRATION_GUIDE.

## Phạm vi đề xuất

1. `FakeClock` mỏng bọc `setDebugTimeOffsetMs`: `advance(Duration)`, `reset()`; tự đặt lại về 0 qua một `dispose()` (không phụ thuộc `flutter_test`). Ghi rõ nó điều khiển `nowMsClamped`/`todayEpochDayClamped`, không điều khiển `DateTime.now()` trực tiếp.
2. Fake có điều khiển: `ConditionedCloudSaveProvider` (fail N lần rồi ok, trả payload hỏng, trễ) và mở rộng `FakePurchaseSeam` (pending/thất bại) nếu một task kiểm thử khác (ENH-125/126) đã tạo mẫu trong `test/support`: TÁI DÙNG, không viết hai bản.
3. Đoạn mẫu trong INTEGRATION_GUIDE cho test widget kit (không thêm API).

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Đọc `consumer_contract_test_kit.dart`, `plugin_adapter_conformance_suite.dart` và các helper trong `test/support`; chốt ranh giới lib/ vs mẫu (ghi trong "Kết quả thực hiện"). Nếu ENH-125/126 đã tạo fake, bắt đầu từ chúng.
- [ ] 2. Viết test TRƯỚC (đỏ) cho `FakeClock`: `advance` đẩy `nowMsClamped` đúng, `reset` về 0, không rò sang test sau; rồi cài đặt.
- [ ] 3. Fake nhà cung cấp có điều khiển: test điều kiện (fail N lần, hỏng, trễ dùng `FakeAsync`), rồi cài đặt.
- [ ] 4. Mutation check từng phần; export + `flutter analyze`, `dart run tool/api_compatibility.dart snapshot` rồi `check`; CHANGELOG.
- [ ] 5. INTEGRATION_GUIDE: đoạn mẫu test, có code chạy được kiểm bằng một test thật (không chép từ trí nhớ).
- [ ] 6. Cổng cuối rồi chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Một consumer test dùng `FakeClock` + fixture của kit để kiểm một hệ thống thời gian (vd `EnergyService` hồi tim) trong dưới 20 dòng.
- [ ] Không thêm phụ thuộc `flutter_test` vào `lib/`.
- [ ] Mọi fake mới có test và mutation check; không có hai bản fake trùng nhau trong repo.

## Lệnh kiểm chứng nhanh

- `flutter test test/core`
- `dart run tool/api_compatibility.dart check`
