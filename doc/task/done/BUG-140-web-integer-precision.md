---
id: BUG-140
title: "Web: số nguyên 64-bit, phép nhân 32-bit và `is int` sai trên JavaScript"
type: bug
layer: lib/core
priority: P1
effort: S
source: "Khảo sát web 2026-11-23: flutter build web thất bại vì literal 0x7FFFFFFFFFFFFFFF; fnv1aHash cho kết quả khác native trên Chrome"
---

## Bối cảnh phạm vi (2026-11-23)

Web KHÔNG phải nền tảng hỗ trợ (owner: chỉ Android và iOS, xem ENH-111). Bug này được phát hiện khi thử biên dịch web, và các sửa được giữ vì (1) không đổi hành vi native (đã kiểm chứng: test VM cũ vẫn pass, vector FNV tính bằng số nguyên chính xác khớp), (2) làm hash `fnv1aHash` đúng theo định nghĩa FNV-1a chuẩn trên mọi môi trường JS, (3) giữ cho kit biên dịch được cho ai thử web, không cam kết hỗ trợ.

## Bằng chứng

- `flutter build web` của app dùng kit thất bại: "The integer literal 0x7FFFFFFFFFFFFFFF can't be represented exactly in JavaScript" tại `purchase_ledger_service.dart:48`, `achievement_service.dart:390`, `daily_quest_service.dart:72`.
- Sau khi sửa, `fnv1aHash` vẫn sai trên Chrome: `(hash * 16777619) & 0xFFFFFFFF` có tích trung gian tới ~2^56 (đo bằng số nguyên chính xác: 56 bit), JS làm tròn nên hash khác native (golden vector `'foobar'`: mong đợi 3826002220, web ra 3826002224).
- Hệ quả đo được: `experiment_bucketing_service_test` (phân phối bucket) đỏ trên Chrome trước khi sửa (giá trị 3039, mong đợi < 1500) và pass sau khi sửa; trên VM luôn pass.
- `fnv1aHash` là nguồn seed cho `ExperimentBucketingService`, `SeededRandomService`, `SeededChallengeService`, `InviteFriendCoordinator`, `PrivacyAwareAnalyticsQueue/Sampler`, `RewardTransactionPipeline`, `RetryErrorState`: cùng input cho kết quả khác nhau giữa web và mobile.

- Bug thứ ba, tìm thấy khi rà helper: `asIntOr(double.infinity, fallback)` trả `Infinity` thay vì `fallback` trên web, vì trên JS `double.infinity is int` là `true` (đo bằng chương trình thử biên dịch sang JS: VM in `false`, JS in `true`). Test BUG-22 sẵn có (`safe_json_test`) đã bắt được lỗi này.

## Đã làm (2026-11-23)

- `lib/core/utils/counter_limit.dart`: `maxCounterValue` = 2^53-1 trên web, int64 đầy đủ trên native (parse từ chuỗi vì compiler web từ chối cả literal nằm trong nhánh không chạy). 3 service và 3 test overflow dùng hằng số này.
- `fnv1aHash`: tách `hash` thành nửa 16-bit để mọi tích < 2^53; kết quả giống hệt native. Chứng minh trước bằng số nguyên chính xác trên 20000 chuỗi ngẫu nhiên (0 sai lệch, tích lớn nhất < 2^53).
- `asIntOr`: kiểm tra `isFinite` cho mọi `num` thay vì chỉ cho `double`, nên `Infinity` trên web rơi về `fallback`.
- Test mới: 24 vector FNV tính bằng số nguyên chính xác (gồm Unicode, chuỗi dài), chạy cả VM lẫn Chrome.

## Kết quả thực hiện

- Kiểm chứng: Chrome với code mới pass; Chrome với code cũ ĐỎ (4 pass, 2 fail), VM với code cũ vẫn pass (native chưa bao giờ sai); các service dùng hash (bucketing, seeded challenge, invite, analytics sampler, seeded random) 78 test pass trên Chrome. Root 4105 pass, example 472 pass, analyze, API gate sạch.
- `asIntOr`: test BUG-22 sẵn có đỏ trên Chrome với code cũ (11 pass, 1 fail), xanh với code mới, VM không đổi (12 pass). Core + widget + presentation VM 3977 pass.
- Rà helper `core/utils`: `SeededRandom` (nhân 32-bit tách 16-bit) đã an toàn, kiểm bằng 200000 cặp ngẫu nhiên (0 sai lệch, tích lớn nhất 33 bit) và 40 test pass trên Chrome; `format.dart`, `retry_policy`, `smart_reminder_scheduling` không có phép toán vượt 2^53.
- Phạm vi chưa phủ: các kiểm tra `value is int` ở nơi khác (`remote_config_service`, `sdk_event_schema_registry`, `storage_service`, `energy_service`, ...) chưa được đánh giá trên web (trên JS, mọi `double` nguyên cũng là `int`, nên phân biệt int/double theo kiểu có thể khác native); chỉ rà bằng grep các hằng lớn, phép dịch bit và nhân với hằng lớn. `EconomyWallet` giới hạn 0x7fffffff nên an toàn trên web.
- Audit / điểm: ~9.2/10. Trừ điểm: chưa có CI Chrome nên lỗi kiểu này chỉ phát hiện khi chạy tay; chưa rà hết mọi phép toán số nguyên trong kit.
- Commit/push:
