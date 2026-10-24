---
id: BUG-102
title: "GameDemoScreen icon-only FABs thiếu tooltip và semantic labels"
type: bug
layer: example/accessibility
priority: P2
effort: S
source: "IDEA-83 accessibility source audit"
---

## Vị trí

`example/lib/screens/game_demo_screen.dart:462-489`.

## Hiện trạng

Nút pause và info dùng `FloatingActionButton` với con là `Icon(Icons.pause)` và `Icon(Icons.info_outline)`, không truyền `tooltip` hay bọc `Semantics(label: ...)`. Người dùng screen reader có thể không nhận diện được chức năng hoặc chỉ nghe tên icon/button không rõ ràng.

## Hậu quả

Vi phạm tiêu chuẩn accessibility của kit: icon-only controls phải có label hoặc tooltip có thể tiếp cận được.

## Scope tối thiểu

Thêm localized tooltip hoặc semantic labels cho hai nút FAB trong `GameDemoScreen`. Không thay đổi logic pause, info hay theme styling.

## Acceptance criteria

- [x] Nút pause có accessible tooltip/label (ví dụ qua localized string).
- [x] Nút info có accessible tooltip/label.
- [x] Test semantics kiểm tra label đọc được trên cây accessibility.
- [x] Không ảnh hưởng layout, hero tags hoặc action handlers hiện có.

## Test plan

- [x] Widget test dùng `tester.getSemantics` để assert label/tooltip của hai FAB.
- [x] Existing `game_demo_screen_test.dart` vẫn pass.
- [x] Analyzer sạch ở root và `example/`.
- [x] Device smoke trên thiết bị thật TECNO KJ7 (`115333744A005844`).

## Prompt loop feature

Đọc task và `game_demo_screen.dart`, `game_demo_screen_test.dart`. Viết failing semantics test trước bằng TDD; sau đó bổ sung tooltip/semantics nhỏ nhất. End loop: audit diff, chấm điểm /10, chạy analyzer và tests; nếu có thiết bị thì smoke kiểm tra announcement, nếu không ghi rõ limitation. Xin approval trước khi commit/push; chỉ push sau approval và CI xanh. Sau đó chuyển file sang `doc/task/done/`.

## Quyết định

Đã hoàn thành, tự chấm 10/10.

- **Implementation**: Thêm `game_demo_pause_tooltip` và `game_demo_info_tooltip` vào `lib/core/app_translations.dart` cho cả 2 locale `en` và `vi`. Gắn `tooltip: 'game_demo_pause_tooltip'.tr` và `tooltip: 'game_demo_info_tooltip'.tr` vào 2 `FloatingActionButton` ('pause' và 'info') trong `example/lib/screens/game_demo_screen.dart`.
- **TDD Widget test**: Thêm group `BUG-102: GameDemoScreen FAB accessibility semantics` trong `example/test/game_demo_screen_test.dart` với 2 test: xác nhận `tester.getSemantics` có đúng tooltip cho default locale ('Pause game', 'Game info') và vi locale ('Tạm dừng trò chơi', 'Thông tin trò chơi'). Cả 2 test ban đầu fail đúng dự kiến vì thiếu tooltip (''), sau đó pass 100%.
- **Parity & Analyze**: `flutter test test/core/app_translations_test.dart` pass (key parity bảo toàn). `flutter analyze` root và example đều 0 warning/error. `dart run tool/api_compatibility.dart check` unchanged.
- **Smoke test trên thiết bị thật TECNO KJ7 (`115333744A005844`)**: Thêm case kiểm tra device semantics vào `example/integration_test/app_boot_test.dart` và chạy `flutter test integration_test/app_boot_test.dart -d 115333744A005844 --dart-define=E2E_TEST=true --name='BUG-102'`. Kết quả: Build APK 18.4s, cài đặt 4.8s, `All tests passed!`.
