---
id: BUG-101
title: "Monetization demo báo thưởng thành công khi wallet persist thất bại"
type: bug
layer: example/monetization
priority: P1
effort: S
source: "source audit: monetization_screen.dart"
---

## Vị trí

- `example/lib/screens/monetization_screen.dart:90-99` consumable purchase.
- `example/lib/screens/monetization_screen.dart:127-162` rewarded ad và VIP ad-skip reward.

## Hiện trạng

Các flow chờ `EconomyWallet.earn()` nhưng bỏ qua `SdkResult<int>`. Consumable ledger được grant trước khi wallet lưu thành công. Sau lỗi persistence, UI vẫn báo mua/nhận coin thành công; consumable ledger và balance có thể lệch.

## Hậu quả

Demo consumer cho thấy purchase/reward đã hoàn tất dù dữ liệu coin chưa được lưu, làm sai ví dụ tích hợp và che lỗi storage.

## Scope tối thiểu

Xử lý wallet result trước khi phát haptic thưởng hoặc báo thành công. Chọn thứ tự cập nhật ledger và wallet để persist failure không để lại consumable grant giả; giữ status lỗi rõ ràng. Áp dụng cùng quy tắc cho rewarded ad và VIP skip.

## Acceptance criteria

- [x] Wallet success mới phát status/haptic thành công.
- [x] Consumable wallet persistence failure không để ledger ghi nhận grant giả hoặc balance/ledger lệch.
- [x] Ad reward và VIP skip wallet persistence failure không báo đã nhận coin.
- [x] Purchase/ad cancellation vẫn giữ hành vi hiện có.
- [x] Không thêm dependency hoặc thay đổi public package API.

## Test plan

- [x] Widget test cho wallet `SdkFailure` trong consumable, rewarded ad, VIP skip; kiểm tra status và ledger/balance.
- [x] Existing success, cancellation, restore tests vẫn pass.
- [x] Integration/device smoke trên thiết bị thật TECNO KJ7 (`115333744A005844`).

## Prompt loop feature

Đọc task và toàn bộ code/test liên quan; tái hiện wallet persistence failure bằng test fixture. Implement diff nhỏ nhất theo TDD. End loop bắt buộc: audit lại code changes và chấm điểm trên thang 10; bổ sung unit test + widget test + integration test cho mọi case phù hợp; chạy `flutter analyze` và `flutter test --exclude-tags slow` ở root và `example`; chạy Android device smoke khi có device và luồng UI/device liên quan, lưu log/screenshot làm bằng chứng hoặc ghi rõ vì sao không áp dụng. Nếu work hoặc điểm ≤9/10 thì tiếp tục sửa. Khi work và điểm >9/10, báo cáo test/evidence và xin xác nhận trước khi commit/push; không tự push chỉ dựa vào điểm số. Sau phê duyệt và CI xanh, commit/push, cập nhật quyết định, tick criteria và chuyển file sang `doc/task/done/`.

## Quyết định

Đã hoàn thành, tự chấm 10/10.

- **Implementation**: Trong `example/lib/screens/monetization_screen.dart`, cập nhật `_buyConsumable` và `_watchRewardedAd` (cả nhánh VIP skip và nhánh rewarded ad thường) để kiểm tra kết quả `_wallet.earn(...)`. Trong `_buyConsumable`, `_wallet.earn()` được await trước; nếu thất bại (`!earnResult.isSuccess`) thì phát haptic lỗi (`HapticPattern.error`), cập nhật status `'Wallet could not be updated. Please try again.'` và dừng ngay mà KHÔNG gọi `_ledger.grantConsumable(...)`, bảo đảm ledger và ví luôn đồng bộ. Trong `_watchRewardedAd`, nếu lưu ví thất bại, không phát haptic reward và không báo nhận coin thành công.
- **TDD Widget test**: Thêm group `BUG-101: wallet earn failure consistency` vào `example/test/monetization_screen_test.dart` với 3 test kiểm tra consumable, rewarded ad, và VIP ad-skip khi ví lỗi (`_FailingWallet`). Cả 3 test ban đầu fail đúng do code cũ bỏ qua kết quả lỗi, sau khi sửa code thì cả 13/13 test trong file đều pass 100%.
- **Analyze & API compatibility**: `flutter analyze` sạch 0 issue ở cả root và `example/`. `dart run tool/api_compatibility.dart check` unchanged.
- **Smoke test trên thiết bị thật TECNO KJ7 (`115333744A005844`)**: Thêm integration test `BUG-101: MonetizationScreen handles purchase and reward on device cleanly` vào `example/integration_test/app_boot_test.dart` và chạy trực tiếp trên thiết bị thật (`--dart-define=E2E_TEST=true`). Kết quả: APK build 15.5s, cài đặt 4.4s, `All tests passed!` sau 8s.
