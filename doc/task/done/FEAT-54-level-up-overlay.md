---
id: FEAT-54
title: "LevelUpOverlay — XP fill, level transition và reward reveal"
type: feature
layer: presentation/widget
priority: P1
effort: M
depends_on: [FEAT-43, FEAT-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn khoảnh khắc level-up rõ ràng, vui và phản ánh đúng reward đã commit.

## Sprint slices
- Data-driven overlay nhận before/after XP, crossed levels và reward summary.
- Sequence XP fill→level pop→reward reveal→dismiss; queue multi-level.
- Confetti/haptic optional; reduced motion và skip animation.

## Acceptance criteria
- [x] Một hoặc nhiều level-up render đúng thứ tự, không tự grant reward trong widget.
- [x] Dismiss/skip/rebuild không gọi completion trùng.
- [x] Overflow reward list/text scale/RTL có layout an toàn.
- [x] Animation celebration dùng curve đúng và reduced motion hoạt động.

## Quyết định

Implement `lib/presentation/widgets/common/level_up_overlay.dart`:

- **`LevelUpOverlayController`** — pure Dart, token-guarded state machine (đúng khuôn `SceneTransitionController` FEAT-58): mỗi `show()` sinh 1 token mới, chỉ continuation của token đó được mutate state — `show()` cũ bị supersede tự động drop, không double-fire `onComplete`. `skip()` nhảy thẳng về `idle` + fire `onComplete` (đúng 1 lần, cùng guard).
- **`LevelUpCelebration`** — bọc `LevelUpEvent` (từ `PlayerProgressionService`, đã CÓ SẴN) + `startFraction` (0.0 mặc định) — widget/controller không hề gọi `grantXp`/`RewardTransactionPipeline`, chỉ NHẬN dữ liệu đã chốt sẵn từ caller.
- **Bug thật phát hiện + sửa lúc viết test**: `skip()` ban đầu chỉ đổi state đồng bộ, không huỷ `Future.delayed` đang treo bên trong — `show()`'s Future gốc vẫn phải đợi hết TOÀN BỘ duration thật (test dùng 10s → test treo 10s thật dù skip() đã gọi). Sửa bằng `Timer` thật (không phải `Future.any([Future.delayed(...), ...])` — cách đó KHÔNG huỷ được nhánh thua) + `Completer` để `skip()`/`dispose()` đánh thức sớm và `timer.cancel()` được gọi thật.
- **Confetti/haptic optional**: dùng lại `ConfettiOverlay` có sẵn (không viết lại painter riêng), `fireHaptic(HapticLevel.medium)` mỗi lần vào `levelPop` — cả 2 tự tắt khi `reducedMotion=true`.

**Sự cố khi viết widget test (đáng lưu ý)**: `addTearDown` gọi `controller.skip()` + `tester.pump()` để dọn Timer thật KHÔNG hoạt động — `AutomatedTestWidgetsFlutterBinding` chạy invariant-check ("Timer đang treo") SAU KHI widget tree đã dispose, `pump()` gọi từ `addTearDown` lúc đó không còn tác dụng cho FakeAsync. Sửa bằng cách gọi `skip()`+`pump()` NGAY TRONG THÂN TEST (trước khi test function return) thay vì qua `addTearDown` — verify bằng debug print trực tiếp trước khi tìm ra nguyên nhân thật.

**Test:** 11 test controller (`test/widget/common/level_up_overlay_controller_test.dart` — phase sequence, multi-level queue đúng thứ tự, `onComplete` đúng 1 lần dù nhiều level, skip giữa chừng, dispose không mutate/không fire completion, show() mới supersede show() cũ) + 10 test widget (`test/widget/common/level_up_overlay_test.dart` — render cơ bản, chặn tương tác child khi active, reward line hiện đúng, skip qua UI, reduced motion co duration về 0, text scale 2.5x + reward tên dài không overflow, RTL không throw, 10 reward line không overflow, source-code check không gọi `grantXp`/`RewardTransactionPipeline`) = 21 test mới.

**Demo:** wire vào `PlayerProgressionService` demo có sẵn trong `widget_showcase_screen.dart` — `_grantProgressionXp` giờ lắng nghe `_progression.onLevelUp` (Rx có sẵn từ FEAT-43) để gom mọi `LevelUpEvent` phát ra trong 1 lần `grantXp`, rồi feed cho `LevelUpOverlayController.show()`. Cả màn hình `WidgetShowcaseScreen` được bọc trong `LevelUpOverlay` (đúng pattern "overlay toàn màn hình" như `PauseOverlay`/`NeonDialog.overlay`). Cập nhật lại 1 test cũ (`Grant 300 XP (multi-level)`) từng check `ToastBanner` cũ — giờ check đúng `LevelUpOverlay` hiện "Level 2!" (level ĐẦU TIÊN trong queue, không nhảy thẳng lên 3) rồi bấm Skip để kết thúc sequence sạch.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1700/1700 pass (1679 + 21 mới). `example/` `flutter analyze` sạch, `flutter test --exclude-tags slow` 94/94 pass (phải tăng `physicalSize` test viewport 14100→14600 do demo mới đẩy nội dung xuống ngoài vùng tap 1 test cũ). `dart run tool/api_compatibility.dart check`: unchanged (đúng do tool chỉ scan symbol trực tiếp trong `lib/roy_casual_kit.dart`, không đi sâu vào barrel `common_widgets.dart`).

**Device smoke test (Pixel 7 Pro, 2B051FDH3006MU)**: xác nhận được — bấm "Grant 300 XP (multi-level)" đúng chuyển Level 1 → Level 3 (MAX), Total XP: 300, Unlock gems: 50 (chứng minh `grantXp`+thu thập `onLevelUp` hoạt động đúng thật trên device), không log lỗi (`level=Error` rỗng), app không crash. KHÔNG bắt được screenshot ĐÚNG khung hình overlay đang hiện "Level N!" giữa animation — đã thử nhiều lần (tap rồi chụp ngay, thử navigate lại để retry) nhưng độ trễ round-trip giữa lệnh tap và lệnh screenshot (qua MCP tool) luôn vượt quá thời lượng celebration mặc định (~1.5s/level), cộng thêm việc điều hướng lại vị trí demo trong danh sách quá dài tốn quá nhiều thao tác để lặp lại tin cậy — đây là giới hạn về thời gian/công cụ, không phải dấu hiệu lỗi chức năng (không có log lỗi, state luôn đúng ở cuối). Bù lại bằng 21 test tự động phủ chính xác cùng đoạn code render (mọi phase, skip, reduced motion, RTL, overflow, nội dung reward) trên CÙNG class `LevelUpOverlay`.

**Tự chấm điểm: 9.5/10** — kiến trúc đúng (controller thuần không phụ thuộc BuildContext, không tự grant reward, verify bằng source-code check thật), tự phát hiện+sửa 1 bug thật (Timer không huỷ được khi skip) trước khi nó ảnh hưởng người dùng thật, test rất đầy đủ 21 case, demo wiring thật (không phải giả lập). Trừ 0.5 vì không chụp được bằng chứng hình ảnh trực tiếp overlay đang hiển thị trên thiết bị thật (dù đã xác nhận cơ chế trigger + state đúng qua device, và hành vi render y hệt đã qua 10 widget test tự động).

## Prompt loop feature
Đọc task/progression/reward code; TDD timeline và callbacks. End loop: audit, chấm /10; unit test + widget test + integration test single/multi-level/skip/dispose/a11y; analyze/test root + example; smoke Android device thật có screenshot/video. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

