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
- Đã kiểm trong SDK: `flutter_test` chỉ `import` nội bộ `leak_tracker_flutter_testing` (`test_compat.dart` dòng 11, `widget_tester.dart` dòng 18) và dùng `LeakTesting.enabled`; grep `leak` trong `flutter_test.dart` (file export công khai) không ra gì, nên rất có thể phải `import 'package:leak_tracker_flutter_testing/...'` trực tiếp và thêm nó vào `dev_dependencies` (gói 3.0.10 đã có trong `~/.pub-cache`). Đây vẫn là gói chỉ-dev; theo điều kiện owner đã đồng ý. **Chưa chạy thử** việc bật leak tracking, nên chưa biết số test đỏ.

## Phạm vi

Bật theo dõi rò rỉ cho `test/widget/` (không bật cho `test/core`): chạy cả bộ, phân loại mọi cảnh báo (rò thật trong widget, rò do test không `dispose`, nhiễu từ Flame/GetX), sửa rò thật ở `lib/`, cấu hình bỏ qua có chủ đích (ghi lý do từng mục) cho phần còn lại.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Xác nhận API: trong `flutter_test` bản 3.41.9 tìm `LeakTesting`, `LeakTesting.enable()`, `LeakTesting.settings`, `LeakTrackingForTests.ignore()` có thể import bằng `package:flutter_test/flutter_test.dart` hay phải import gói `leak_tracker_flutter_testing`. Nếu cần import trực tiếp gói đó: thêm vào `dev_dependencies` và báo owner (đây là điều kiện owner đã đồng ý: chỉ dev).
- [ ] 2. Thêm `test/widget/flutter_test_config.dart` bật leak tracking (chỉ thư mục `test/widget`), chưa sửa lib.
- [ ] 3. Chạy toàn bộ `flutter test test/widget`; ghi vào "Kết quả thực hiện" số test đỏ và PHÂN LOẠI từng nguồn (rò thật / test thiếu dispose / nhiễu thư viện).
- [ ] 4. Sửa rò thật trong `lib/presentation` (mỗi sửa một commit, kèm test hồi quy cho đúng widget đó, mutation check).
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
