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

- [ ] Mỗi mục có ít nhất 1 test; liệt kê file test mới.
- [ ] AdReward test giữ vendor-neutral, không thêm SDK quảng cáo.
- [ ] RuntimeFlags/DebugLog test không phụ thuộc platform channel.
- [ ] Common widgets barrel import smoke compile.
- [ ] PauseOverlay system-reason Resume covered sau BUG-92.
- [ ] Consumer contract fixture được demo trong example hoặc có lý do ghi rõ + unit contract coverage.

## Quyết định

_(điền sau khi implement + push: implementation, TDD, kết quả analyze/test, tự chấm điểm)_

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
