---
id: IDEA-71
title: "Test coverage sweep"
type: idea
priority: P2
effort: S
source: "fork audit core + verify phiên chính"
---

## Vị trí

`lib/core/ad_reward_seam.dart`; `lib/core/runtime_flags.dart`; `lib/core/debug_log.dart`; `lib/presentation/widgets/common/common_widgets.dart`; `lib/presentation/widgets/common/pause_overlay.dart`; `lib/core/consumer_contract_test_kit.dart`; `example/lib/screens/monetization_screen.dart:25,48,67-68`.

## Hiện trạng

`AdRewardSeam` có demo neutral `_DefaultDemoAdRewardAdapter` trong MonetizationScreen, và contract test cho `FakeAdRewardSeam`, nhưng cần audit test demo flow riêng. `RuntimeFlags` chỉ là `const isE2eTest`; `DebugLog` chỉ `kDebugMode` wrapper. Barrel `common_widgets.dart` chỉ được reference từ showcase test, không thấy import/export contract test. Nhánh system-reason Resume của `PauseOverlay` chưa có coverage (BUG-92). Không thấy demo `RoyCasualKitTestFixture`/`RoyCasualKitContractTestKit` trong `example/lib`; chỉ có device integration test dùng fixture.

## Vì sao cần / Hậu quả

Các seam/flag/barrel nhỏ dễ regress vì coverage không trực tiếp kiểm chứng public contract và demo behavior.

## Đề xuất

Mỗi mục thêm ≥1 test tối thiểu: AdReward demo neutral (không vendor SDK); RuntimeFlags build-time behavior; DebugLog release/debug contract; barrel import smoke; PauseOverlay system-resume sau BUG-92; consumer contract fixture tile/demo trong example hoặc unit contract nếu không thêm UI hợp lý. Liệt kê file test mới trong quyết định.

## Acceptance criteria

- [x] Mỗi mục có ít nhất 1 test; liệt kê file test mới.
- [x] AdReward test giữ vendor-neutral, không thêm SDK quảng cáo.
- [x] RuntimeFlags/DebugLog test không phụ thuộc platform channel.
- [x] Common widgets barrel import smoke compile.
- [x] PauseOverlay system-reason Resume covered sau BUG-92.
- [x] Consumer contract fixture được demo trong example hoặc có lý do ghi rõ + unit contract coverage.

## Quyết định

File test mới/mở rộng:
- `test/core/ad_reward_seam_test.dart` (mới) — `.maybe` null/registered, fake seam vendor-neutral, trả reward đúng/sai.
- `test/core/runtime_flags_test.dart` (mới) — `isE2eTest == false` mặc định trong host test run, không đụng platform channel.
- `test/core/debug_log_test.dart` (mới) — capture `debugPrint`, verify prefix `roy93~ ` chính xác.
- `test/widget/common/common_widgets_barrel_test.dart` (mới) — chỉ import barrel `common_widgets.dart`, compile/resolve độc lập, không phụ thuộc `example/`.
- `test/widget/common/pause_overlay_test.dart` (mở rộng) — thêm case BUG-92: `showForSystemPause: false` + cả user lẫn system pause cùng lúc, back button chỉ gỡ user, overlay ẩn đúng khi chỉ còn system pause.
- `test/core/consumer_contract_test_kit_test.dart` (mở rộng) — thêm idempotency test (double bootstrap qua `verifyBootstrap` nội bộ) và no-network/in-memory-storage-only assertion.
- `example/lib/screens/cookbook_screen.dart` + `example/test/cookbook_screen_test.dart` — tile mới "RoyCasualKitContractTestKit — verifyBootstrap (consumer contract)" chạy `RoyCasualKitContractTestKit.verifyBootstrap` thật, hiện `passed=true`; test riêng xác nhận tile chạy thật.

Test: tất cả file trên chạy pass độc lập; không ảnh hưởng 2571 test gốc.

Gates: root+example `flutter analyze` sạch; root+example `flutter test --exclude-tags slow` pass toàn bộ (2601 root / 206 example).

Tự chấm: 9.5/10 — coverage đúng mục tiêu từng seam/flag/barrel nhỏ, vendor-neutral giữ nguyên, không thêm phụ thuộc platform/SDK mới.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã verify AdReward demo tại `example/lib/screens/monetization_screen.dart` và vendor-neutral seam; grep test có conformance test. `RuntimeFlags`/`DebugLog` mỗi file rất nhỏ, barrel chỉ thấy showcase test reference, consumer fixture không thấy trong `example/lib` nhưng có device integration use. PauseOverlay finding phụ thuộc BUG-92.
