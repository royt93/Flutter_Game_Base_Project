---
id: BUG-103
title: "GameDemoScreen Pause FAB bị cắt ở mép trên và không nhận chạm khi landscape"
type: bug
layer: example/game-demo
priority: P2
effort: S
source: "TECNO KJ7 landscape device check 2026-11-10"
---

## Vị trí

`example/lib/screens/game_demo_screen.dart:462-489` (cột FAB pause/info) và
`example/lib/main.dart:56` (`SystemChrome.setPreferredOrientations`).

## Hiện trạng

Example hiện khóa portrait. Khi tạm mở landscape trên TECNO KJ7 (2436×1080) để kiểm tra
`PauseOverlay`, cột FAB nằm sát mép trên màn hình: Pause FAB có bounds `[2220,0][2388,144]`
và hiển thị bị cắt ở mép trên. Chạm vào tâm FAB và thử chuyển focus bằng bàn phím không mở
được `PauseOverlay`; FAB Info bên dưới vẫn mở dialog bình thường.

## Hậu quả

Người dùng không thể pause từ UI khi demo chạy landscape, nên không kiểm chứng được
`PauseOverlay` trong viewport ngang trên thiết bị thật. Widget test hiện tại chỉ chứng minh
`PauseOverlay` không overflow ở `640×320` và `568×320`.

## Scope tối thiểu

Trước khi sửa, tái hiện bằng widget test landscape cho `GameDemoScreen`, xác định nguyên nhân
(vị trí bị tràn lên mép trên/inset hay vùng chạm bị chắn). Sau đó đặt cột FAB trong `SafeArea`
hoặc bù lại layout landscape. Chỉ mở landscape cho example nếu quyết định app hỗ trợ landscape;
không đổi orientation mặc định chỉ để demo.

## Acceptance criteria

- [x] Widget test landscape cho `GameDemoScreen`: Pause FAB nằm hoàn toàn trong viewport và chạm mở được `PauseOverlay` (`BUG-103` trong `example/test/game_demo_screen_test.dart`, viewport TECNO 2436×1080 @3x; fail `-8.0` trước khi sửa).
- [ ] Kiểm tra TECNO KJ7 thật ở landscape: Pause FAB chạm được, panel Paused hiển thị, cuộn/chạm tới Quit không overflow. **Chưa thực hiện** — đóng task theo quyết định của owner (2026-11-11) dựa trên widget test; example vẫn khóa portrait tại `example/lib/main.dart:56`, nên cần quyết định hỗ trợ landscape trước khi kiểm tra máy thật.
- [x] Giữ nguyên portrait layout, hero tags, tooltip/semantics và action handlers hiện có (portrait vẫn `bottom: 240` dạng cột; 442 test example pass).

## Test plan

- [x] Widget test dùng viewport landscape và `tester.tap` vào Pause FAB.
- [x] `flutter analyze` và `flutter test --exclude-tags slow` pass ở `example/`.
- [ ] Device smoke trên TECNO KJ7 sau khi quyết định hỗ trợ landscape (chưa thực hiện).

## Constraints

- Chỉ code trên `main`, không branch/worktree.
- Không đổi orientation mặc định của example khi chưa có quyết định hỗ trợ landscape.

## Kết quả

Sửa trong commit `da9e2020`: ở landscape cột FAB đổi thành hàng ngang neo `top: 8`; portrait giữ nguyên. Các tiêu chí thiết bị thật vẫn mở; nếu sau này example hỗ trợ landscape, tạo task kiểm tra riêng trên TECNO KJ7.
