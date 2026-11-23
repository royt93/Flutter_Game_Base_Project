---
id: BUG-140
title: "Web: số nguyên 64-bit và phép nhân 32-bit sai trên JavaScript"
type: bug
layer: lib/core
priority: P1
effort: S
source: "Khảo sát web 2026-11-23: flutter build web thất bại vì literal 0x7FFFFFFFFFFFFFFF; fnv1aHash cho kết quả khác native trên Chrome"
---

## Bằng chứng

- `flutter build web` của app dùng kit thất bại: "The integer literal 0x7FFFFFFFFFFFFFFF can't be represented exactly in JavaScript" tại `purchase_ledger_service.dart:48`, `achievement_service.dart:390`, `daily_quest_service.dart:72`.
- Sau khi sửa, `fnv1aHash` vẫn sai trên Chrome: `(hash * 16777619) & 0xFFFFFFFF` có tích trung gian tới ~2^56 (đo bằng số nguyên chính xác: 56 bit), JS làm tròn nên hash khác native (golden vector `'foobar'`: mong đợi 3826002220, web ra 3826002224).
- Hệ quả đo được: `experiment_bucketing_service_test` (phân phối bucket) đỏ trên Chrome trước khi sửa (giá trị 3039, mong đợi < 1500) và pass sau khi sửa; trên VM luôn pass.
- `fnv1aHash` là nguồn seed cho `ExperimentBucketingService`, `SeededRandomService`, `SeededChallengeService`, `InviteFriendCoordinator`, `PrivacyAwareAnalyticsQueue/Sampler`, `RewardTransactionPipeline`, `RetryErrorState`: cùng input cho kết quả khác nhau giữa web và mobile.

## Đã làm (2026-11-23)

- `lib/core/utils/counter_limit.dart`: `maxCounterValue` = 2^53-1 trên web, int64 đầy đủ trên native (parse từ chuỗi vì compiler web từ chối cả literal nằm trong nhánh không chạy). 3 service và 3 test overflow dùng hằng số này.
- `fnv1aHash`: tách `hash` thành nửa 16-bit để mọi tích < 2^53; kết quả giống hệt native. Chứng minh trước bằng số nguyên chính xác trên 20000 chuỗi ngẫu nhiên (0 sai lệch, tích lớn nhất < 2^53).
- Test mới: 24 vector FNV tính bằng số nguyên chính xác (gồm Unicode, chuỗi dài), chạy cả VM lẫn Chrome.

## Kết quả thực hiện

- Kiểm chứng: Chrome với code mới pass; Chrome với code cũ ĐỎ (4 pass, 2 fail), VM với code cũ vẫn pass (native chưa bao giờ sai); các service dùng hash (bucketing, seeded challenge, invite, analytics sampler, seeded random) 78 test pass trên Chrome. Root 4105 pass, example 472 pass, analyze, API gate sạch.
- Phạm vi chưa phủ: các nơi khác nhân/dịch bit số lớn chưa được rà hệ thống; chỉ rà bằng grep các phép nhân với hằng ≥ 7 chữ số và hằng int64, không thấy chỗ khác. `EconomyWallet` giới hạn 0x7fffffff nên an toàn trên web.
- Audit / điểm: ~9.2/10. Trừ điểm: chưa có CI Chrome nên lỗi kiểu này chỉ phát hiện khi chạy tay; chưa rà hết mọi phép toán số nguyên trong kit.
- Commit/push:
