---
id: ENH-117
title: "Bật leak tracking (LeakTesting) cho test widget để chứng minh không rò Ticker/Controller/Stream"
type: enhancement
layer: test/widget + test config
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- `lib/presentation` có **71 file** giữ `AnimationController`/`Ticker`/`Timer`/`StreamSubscription`; **68** có `dispose()` riêng. 3 file không có: `neon_aura_layer.dart` và `aurora_bg_layer.dart` kế thừa `ShaderTickerLayerState` (đã `dispose` ticker + shader ở base), `network_status_banner.dart` là `StatelessWidget` (không giữ gì). Quét tĩnh không thấy rò rõ ràng.
- Chưa có `flutter_test_config.dart` ở `test/` hay `test/widget/`; chưa dùng `LeakTesting` ở đâu trong repo.
- Flutter 3.41.9: `flutter_test` phụ thuộc `leak_tracker_flutter_testing: 3.0.10`; doc của `testWidgets` nói chỉnh `LeakTesting.settings` trong `flutter_test_config.dart`. Owner chấp nhận bật cấu hình này (không thêm package ngoài `flutter_test`).
- (Đã kiểm, xem "Kết quả" bên dưới) `flutter_test` chỉ `import` nội bộ `leak_tracker_flutter_testing` (`test_compat.dart` dòng 11, `widget_tester.dart` dòng 18) và dùng `LeakTesting.enabled`; grep `leak` trong `flutter_test.dart` (file export công khai) không ra gì, nên rất có thể phải `import 'package:leak_tracker_flutter_testing/...'` trực tiếp và thêm nó vào `dev_dependencies` (gói 3.0.10 đã có trong `~/.pub-cache`). Đây vẫn là gói chỉ-dev; theo điều kiện owner đã đồng ý. **Chưa chạy thử** việc bật leak tracking, nên chưa biết số test đỏ.

## Phạm vi

Bật theo dõi rò rỉ cho `test/widget/` (không bật cho `test/core`): chạy cả bộ, phân loại mọi cảnh báo (rò thật trong widget, rò do test không `dispose`, nhiễu từ Flame/GetX), sửa rò thật ở `lib/`, cấu hình bỏ qua có chủ đích (ghi lý do từng mục) cho phần còn lại.

## Các bước (mỗi bước một commit, tick khi xong)

- [x] 1. Xác nhận API: trong `flutter_test` bản 3.41.9 tìm `LeakTesting`, `LeakTesting.enable()`, `LeakTesting.settings`, `LeakTrackingForTests.ignore()` có thể import bằng `package:flutter_test/flutter_test.dart` hay phải import gói `leak_tracker_flutter_testing`. Nếu cần import trực tiếp gói đó: thêm vào `dev_dependencies` và báo owner (đây là điều kiện owner đã đồng ý: chỉ dev).
- [x] 2. Thêm cấu hình bật leak tracking. THAY ĐỔI so với kế hoạch (owner chọn "bật dần"): không đặt ở `test/widget/flutter_test_config.dart` (sẽ làm 76 test đỏ), mà ở thư mục riêng `test/widget/leaks/` (`flutter_test_config.dart` + `widget_leaks_test.dart`); mở rộng dần khi các thư mục khác sạch.
- [x] 3. Chạy toàn bộ `flutter test test/widget`; ghi vào "Kết quả thực hiện" số test đỏ và PHÂN LOẠI từng nguồn (rò thật / test thiếu dispose / nhiễu thư viện).
- [x] 4. Sửa rò thật trong `lib/presentation` (mỗi sửa một commit, kèm test hồi quy cho đúng widget đó, mutation check).
- [ ] 5. Với phần còn lại: sửa test (dispose đúng) hoặc cấu hình bỏ qua có chủ đích, mỗi mục kèm lý do trong comment ngắn; không bỏ qua cả thư mục.
- [ ] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi số liệu trước/sau, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Leak tracking bật cho `test/widget` và cả bộ pass.
- [ ] Mọi mục bỏ qua có lý do cụ thể, không bỏ qua cả thư mục.
- [ ] Không rò Ticker/AnimationController/Stream nào còn lại ở widget trong `widgets/common` mà chưa có giải thích.
- [ ] Không thêm dependency ngoài `dev_dependencies` (nếu có, đã báo owner).

## Lệnh kiểm chứng nhanh

- `flutter test test/widget/common`
- `flutter test test/widget/goldens (chỉ trên CI Linux)`

## Kết quả đợt 1 (2026-11-24, CHƯA đóng task)

**Đã đo thật** (bật `LeakTesting.enable()` cho cả `test/widget`, baseline 145 test golden đỏ sẵn trên macOS): ban đầu 101 test đỏ thêm vì rò rỉ. Nguyên nhân, đo trên 101 báo cáo: 32 chỉ rò `CurvedAnimation` (lỗi thật của lib), 43 gồm state/controller của chính kit hoặc test không dỡ, 26 chỉ là rác khung test (route/overlay).

**Sửa trong lib (28 file, +159/-70):**
- `CurvedAnimation` không dispose: 25 chỗ ở 21 file. 14 chỗ nằm trong `build()` (mỗi lần dựng lại thêm một status listener vào controller mà không bao giờ gỡ): đổi sang `CurveTween(...).animate(parent)` (không thêm listener, trả đúng giá trị; đã chứng minh bằng test số học tạm 4 curve x 101 điểm, bằng nhau tuyệt đối) hoặc giữ làm field có `dispose()`. `NeonDialog` có animation tuỳ chỉnh `_DialogScaleAnimation` giữ easeOutBack khi vào, easeIn khi ra.
- `TextPainter` không dispose: `wheel_spinner`, `coin_multiplier_wheel`, `share_helper`, `label_fit` (nhánh đo thật).
- `OverlayEntry` không dispose sau `remove()`: `toast_banner`, `floating_combo_text`, `coin_fly_overlay`, có chặn gọi hai lần.
- Rx/ValueNotifier không đóng: `StorageService` (thêm `onClose()` dispose hai notifier; **API snapshot +1 dòng**), `LevelUpOverlayController`, `SceneTransitionController`.

**Kiểm chứng:** analyze sạch, root 4200 test pass (không golden), example 475 pass, 5 quality-gate xanh. `test/widget/leaks/` (thư mục MỚI có `flutter_test_config.dart` bật leak tracking, 8 test): mutation cho 7 widget (bỏ dispose / đưa lại `CurvedAnimation` trong build) đều làm đúng 1 test đỏ. Thêm test hồi quy cho `NeonDialog` (2 test, mutation 2/3 đỏ) và `radial_action_menu` (stagger + overshoot, mutation đỏ).

**Sai sót đã sửa trong lúc làm (ghi để khỏi lặp):** task ghi "flutter_test đã export LeakTesting": SAI, phải `import 'package:leak_tracker_flutter_testing/...'` và thêm nó vào `dev_dependencies` (đã có trong lock cùng phiên bản 3.0.10, chỉ đổi 1 dòng lock; owner đã đồng ý). Script sửa hàng loạt test (`WheelSpinnerController` inline) làm hỏng 4 chỗ và thêm trùng `addTearDown` (gây "used after being disposed"): đã hoàn tác và làm tay.

**CHƯA làm (nên task còn trong `todo/`):** theo lựa chọn của owner ("commit sửa lib, bật tracking dần") KHÔNG bật leak tracking toàn cục cho `test/widget`. Đo lúc bật toàn cục: 76 test đỏ mới (60 file rò): `flame_tracked_overlay_test` (156 `NotifyingVector2`, nhiều khả năng của Flame), `debug_qa_overlay_test` (52 `ValueNotifier`), `viewport_sweep_test` (51), 40 file golden (đã giảm nhiều nhờ harness `runGoldenMatrix` unmount ở `finally`, còn 1 rò/ file ở vài test). `test/widget/common` còn 15 file rò (101 -> 15), phần lớn do test không dispose `WheelSpinnerController`/`ScreenShakeController`/`Tutorial...` ở `viewport_sweep` và state/element của một số widget (`battle_pass_road`, `candy_search_bar`...) chưa điều tra.

## Kết quả đợt 2 (2026-11-24, task vẫn mở)

- `test/widget/common` đã SẠCH rò rỉ và leak tracking đã BẬT cho cả thư mục (`test/widget/common/flutter_test_config.dart`): 1929 test pass, 0 file rò (từ 15). Đã kiểm tracking thật sự bật: bỏ `_scaleCurve.dispose()` của `StreakCounter` làm test đỏ, khôi phục thì xanh.
- Sửa test (không phải lib): thêm `addTearDown(...dispose)` cho `CardFlip3DController`, `RewardSequenceController`, `ValueNotifier`, `TextPainter` do test tự tạo; `OverlayEntry` do test tự tạo; `StorageService` qua helper mới `test/support/owned_storage.dart`; 3 controller dựng trong builder của `viewport_sweep_test` qua helper `owned*Controller()` (dispose cuối test).
- 7 test kiểm tra `ArgumentError` từ `initState` (`ExpandablePanel`, `CurrencyCounter`, `BattlePassRoad`...) dùng `experimentalLeakTesting: ignoringFailedInitState('<State>')` (`test/support/leak_ignores.dart`): khi `initState` ném, Flutter giữ Element/State nửa dựng mà không dispose, đó là hành vi của framework không phải rò của widget. Bỏ qua CHỈ các lớp đó, CHỈ trong test đó.
- Lib: `ToastBanner.show` thêm `onDisposed` để giải phóng `OverlayEntry` cả khi cả Overlay bị gỡ lúc toast đang hiện (trước chỉ giải phóng khi toast tự đóng); `remove()` gọi không điều kiện một lần rồi `dispose()` (SDK: `dispose` yêu cầu đã `remove`; `remove` trả sớm nếu overlay đã gỡ). Mutation: 3 biến đổi (không giải phóng khi gỡ overlay, `remove` có điều kiện `mounted` như bug cũ, bỏ chặn gọi hai lần) đều làm test đỏ.
- Kiểm chứng: analyze sạch, root 4188 pass (không gồm golden), example 475 pass, API gate unchanged, 5 quality-gate xanh.
- Sai sót trong lúc làm: chạy `dart format` lên 7 file test làm diff phình (+53 -31 so với +4 -1 thật); đã hoàn tác và sửa tối thiểu, đo bằng `git diff -w`. Ngoài ra script ghi tài liệu của tôi dừng ở một `assert` nhưng lệnh `git commit` trong cùng dòng vẫn chạy, nên commit `82f18765` thiếu CHANGELOG và file task; commit này bổ sung.
- **Còn lại để đóng task:** các cụm lớn ngoài `common`: `flame_tracked_overlay_test` (156 rò `NotifyingVector2`/`Transform2D`, nhiều khả năng của Flame: cần đọc), `debug_qa_overlay_test` (52 `ValueNotifier`), `flame_tracked_overlay_benchmark_test`, ~40 file golden (harness `runGoldenMatrix` đã unmount ở `finally`, còn rò lẻ ở vài test), cùng các test gốc `test/widget/*.dart`. Chưa chạy lại golden trên Linux (golden đỏ sẵn trên macOS theo thiết kế).

## Sự cố CI sau đợt 1 (2026-11-24): 76 golden đỏ do tôi, đã sửa

- Commit `f2e91742` thêm vào `runGoldenMatrix` (`test/support/golden_matrix.dart`) một bước `pumpWidget(SizedBox.shrink())` trong `finally` để leak tracking thấy widget được dỡ. Nhưng 43 chỗ trong 11 file golden gọi `find.byKey(target)` / `matchesGoldenFile` SAU KHI `runGoldenMatrix` trả về, nên widget đã bị dỡ: "Found 0 widgets with key ... could not be rendered". CI `analyze-test` đỏ: 4477 pass, 76 fail (cả 76 là golden). `quality-gate` xanh.
- Vì sao tôi không thấy: trên macOS các golden này đỏ sẵn (145 test, so ảnh Linux), nên 76 test đỏ mới bị chìm trong 145 đỏ cũ. Tôi đã so "đỏ mới" trước khi bật tracking toàn cục nhưng KHÔNG so lại sau khi thêm bước dỡ widget, và đợt 1 chỉ chạy `test/widget/common` + `leaks` trước khi commit, không chạy `test/widget/goldens`.
- Sửa: hoàn tác bước dỡ widget; file harness giờ giống hệt trước `f2e91742`. Kiểm: chạy toàn bộ `test/widget` khớp baseline 145/145, 0 test mới đỏ, 0 lỗi "no widget was found". Hệ quả: ~40 file golden sẽ rò lẻ khi bật tracking (đo ở trên); cách đúng để xử lý là dỡ widget ở chính các test gọi sau harness hoặc thêm tham số `unmountAtEnd` cho harness (mặc định tắt), không đổi hành vi mặc định.
- Bài học: sau khi sửa file dùng chung (`test/support/*`), chạy cả thư mục test dùng nó và so "đỏ mới" với baseline TRƯỚC khi commit; nhất là khi baseline đã đỏ sẵn trên máy cục bộ.

## Hồi quy do chính ENH-117 đợt 1, phát hiện và sửa (2026-11-24)

- Đợt 1 (`f2e91742`) làm `LevelUpOverlayController.dispose()` và `SceneTransitionController.dispose()` đóng các `Rx` của chúng. Khi app dispose controller TRƯỚC lúc widget overlay unmount (thứ tự thường gặp: một State cha dispose controller trong `dispose()`), `Obx.dispose` đóng lại `Rx` đã đóng và ném `TypeError: Null check operator used on a null value` trong `GetStream.removeSubscription`.
- Phát hiện: khi viết golden đợt B (ENH-119), một lỗi `GetStream.removeSubscription` xuất hiện trong test; bắt nguồn bằng cách chạy riêng, rồi dựng probe: so cùng kịch bản (dispose rồi unmount) ở `0e3ecb0c` (trước ENH-117: 2/2 pass) với `HEAD` (2/2 đỏ).
- Chưa phát hành bản nào chứa lỗi này (chỉ nằm trong `## Unreleased`).
- Sửa (owner chọn hoàn tác): bỏ `phase.close()`, `queueIndex.close()`, `progress.close()` khỏi hai `dispose()`, kèm comment lý do. Test hồi quy mới ở `level_up_overlay_test.dart` và `scene_transition_overlay_test.dart` (dispose controller rồi unmount, không được ném); đỏ trước khi sửa, xanh sau; mutation (đóng lại Rx) làm đỏ.
- Quét thêm các thay đổi khác của đợt 1 để tìm hazard cùng loại (đo bằng probe): `StorageService.onClose` đóng trước service lắng nghe (không ném); `ToastBanner`/`FloatingComboText` bị gỡ cả overlay giữa chừng (không ném); `RoyCasualKit.resetForTesting` khi consumer còn ví (không ném, ví vẫn dùng được). MỘT hành vi mới đã ghi vào CHANGELOG: `importAll`/`eraseAll`/thao tác theo prefix trên `StorageService` đã `onClose()` ném `FlutterError` (đúng như mọi `ChangeNotifier` đã dispose); đọc, `setX`, `remove` vẫn chạy.
- Sai sót của tôi: thêm `dispose` cho Rx mà không kiểm thứ tự dispose cha/con. Test leak-tracking dispose controller sau khi widget đã unmount nên không bắt được. Bài học: với mọi thay đổi `dispose()`, probe cả hai thứ tự.
