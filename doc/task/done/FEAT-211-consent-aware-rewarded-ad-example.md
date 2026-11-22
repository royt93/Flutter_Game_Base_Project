---
id: FEAT-211
title: "Ví dụ rewarded ad thật, opt-in và consent-gated"
type: feature
layer: example/monetization
priority: P2
effort: L
source: "Full source audit 2026-11-21; monetization demo uses fake AdRewardSeam only"
---

## User story

Là developer tích hợp kit, tôi muốn xem adapter rewarded-ad thực sự nhưng opt-in để hiểu consent/init/reward boundaries, trong khi default example vẫn không gọi ad network.

## Bằng chứng / giới hạn hiện tại

- `example/lib/screens/monetization_screen.dart` dùng `_DefaultDemoAdRewardAdapter`, demo-only.
- `example/pubspec.yaml` hiện không tích hợp ad SDK production.
- Repo có các consent state/demo seams, nhưng chưa xác nhận policy/SDK/provider cho sample thật.

## Gate trước khi bắt đầu

Owner phải chọn ad provider/SDK, policy consent/UMP, app IDs, test device hashes riêng theo app/package/certificate/variant, và xác nhận store/privacy requirements. Không tái dùng hash/IDs từ app khác. Nếu release test-device safety chưa thể chứng minh mà không request ad thật, không chạy ad request/device smoke; dừng chờ owner.

## Acceptance criteria

- [ ] Default app path tiếp tục dùng fake adapter; live adapter chỉ bật bằng explicit configuration/opt-in.
- [ ] Consent gate chạy trước initialize/request; reward chỉ cấp sau callback completion hợp lệ từ provider.
- [ ] Debug và release test-device configuration được kiểm tra tách biệt bằng hash đúng package+signing variant; stale/missing hash khiến smoke dừng trước request.
- [ ] Provider failure, cancel, duplicate callback, concurrent tap và consent revoke được test ở unit/widget phù hợp.
- [ ] Integration/device proof dùng test ads hoặc no-ad preflight đã xác minh; nếu thấy/không chắc ad là test, force-stop và hỏi owner ngay.
- [ ] Audit code changes và score >9/10 (safety/consent 4, correctness 2, tests 2, architecture 1, device proof 1).
- [ ] Unit + widget + integration coverage cho relevant cases; physical device thật, không simulator. Ghi model/OS/build/commit/log và test ad proof.

## Prompt loop

Trước khi code, hỏi owner mọi quyết định gate còn thiếu (provider, consent, app IDs, package/build hash). Không suy đoán hay dùng ad real trong smoke. Đọc toàn bộ `AdRewardSeam`, consent flows, monetization tests, Android/iOS config. Viết fake/provider contract tests trước, implement opt-in sample tối thiểu, không đổi default fake path. Test unit/widget/integration: consent denied/granted, success/cancel/error, duplicate completion, concurrent requests, release/debug safety. Chạy analyze và physical-device smoke chỉ sau khi test-device recognition được xác nhận bằng safe preflight. Nếu bất kỳ log nào chỉ `Use RequestConfiguration...`, có ad real, hoặc không phân biệt chắc test/live, force-stop ngay và hỏi owner. Audit code changes, score /10 theo rubric; lặp tới >9/10 và mọi gate đạt. Dừng nếu test ad safety/provider policy chưa đủ. Chỉ khi đạt tất cả và score >9/10 mới ghi kết quả và push code.

## Kết quả thực hiện

- Provider/consent decision:
- Test IDs / build variants verified:
- Audit / điểm:
- Unit/widget/integration:
- Physical-device smoke:
- Commit/push:
- Rủi ro còn lại:

## Kết quả thực hiện

- **Won't-do (2026-11-22).** Owner quyết định không cần tính năng ad trong kit vì đã phát triển ad SDK riêng; kit chỉ tập trung tính năng làm game. Không thêm `google_mobile_ads`, không làm adapter live.
- Thay vì thêm, đã gỡ toàn bộ tính năng ad hiện có trong 0.8.0 (BREAKING): `AdRewardSeam`, `RewardedAdResultCard`/`RewardedAdStatus`, `verifyAdRewardSeam`/`FakeAdRewardSeam`, demo ad trong `monetization_screen.dart`, 28 golden `wave27_ad_*`. Xem `CHANGELOG.md` mục 0.8.0.
