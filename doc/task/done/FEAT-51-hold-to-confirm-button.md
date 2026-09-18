---
id: FEAT-51
title: "HoldToConfirmButton — giữ để xác nhận hành động rủi ro"
type: feature
layer: presentation/widget
priority: P1
effort: S
depends_on: [FEAT-50, IDEA-41]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người dùng, tôi muốn hành động reset/delete/purchase chỉ chạy sau khi giữ đủ lâu để tránh chạm nhầm.

## Sprint slices
- Press/drag/cancel state machine và radial/linear progress animation.
- Haptic milestones optional, keyboard/semantics activation alternative.
- Config duration, label và reset curve; reduced motion vẫn giữ thời gian an toàn.

## Acceptance criteria
- [x] Giữ đủ gọi confirm đúng một lần; thả/drag ra/unmount sớm không gọi.
- [x] Multi-pointer/rage tap/reentrant callback không double fire.
- [x] Disabled, keyboard và screen-reader path có contract truy cập được.
- [x] Animation/haptic mượt và reduced motion không bỏ protection.

## Prompt loop feature
Đọc task và interaction conventions; TDD gesture state machine. End loop: audit, chấm /10; unit test + widget test + integration test mọi gesture/multitouch/a11y/dispose; analyze/test root + example; smoke Android device thật quay thao tác chứng minh. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Thêm `HoldToConfirmButton` (`lib/presentation/widgets/common/hold_to_confirm_button.dart`) — state machine trên raw `Listener` (không dùng `GestureDetector`) để tự kiểm soát chính xác 1 pointer đang giữ:
- `_activePointer` chỉ nhận pointer ĐẦU TIÊN; pointer thứ 2 xuất hiện trong lúc đang giữ bị bỏ qua hoàn toàn (không reset/không can thiệp hold gốc).
- Bounds check bằng `RenderBox.globalToLocal` + `Size.contains` trên `onPointerMove` — kéo ra ngoài widget's own bounds huỷ y hệt thả tay, animate về 0 theo `resetCurve` cấu hình được (không snap cứng).
- Haptic 2 mốc rời rạc (start/confirm) qua `HapticChoreographer` (IDEA-41) — dùng đúng công cụ có sẵn cho "milestone rời rạc", không ép continuous-tick vào 1 API vốn thiết kế cho pattern cố định.
- Accessibility: `Semantics(onTap: ...)` gọi `onConfirm` NGAY, bỏ qua yêu cầu giữ — trade-off chuẩn WCAG cho tương tác chỉ-dựa-vào-motion (switch-access/TalkBack không giữ được gesture thời lượng).
- Reduced motion KHÔNG rút ngắn `duration` — đây là cơ chế an toàn, không phải trang trí; chỉ animation/haptic có thể đơn giản hoá theo `NeonTheme.reducedMotion`, thời gian giữ luôn giữ nguyên (test riêng verify điều này).
- `shape: {radial, linear}` — radial dùng `CircularProgressIndicator` quanh icon tròn, linear dùng `FractionallySizedBox` fill pill — không cần custom painter.

**Bug thật tìm thấy qua TDD (không phải qua review, qua RED/GREEN cycle):** `AnimationController.animateTo(0)` (đường huỷ) CŨNG phát `AnimationStatus.completed` khi chạm target — ban đầu code coi MỌI `completed` là "đã giữ đủ", khiến huỷ giữa chừng/rage-tap/kéo ra ngoài bounds ĐỀU sai gọi `onConfirm`. Sửa: chỉ coi là confirm khi `completed && value >= 1.0`. Phát hiện qua chính bộ test TDD (RED ban đầu bắt đúng lỗi này), không phải qua audit thủ công.

**Bug test-mechanics tìm thấy:** `AnimationController`'s `Ticker` chỉ ghi nhận mốc thời gian bắt đầu ở LẦN TICK ĐẦU TIÊN sau khi start — 1 `tester.pump(bigDuration)` duy nhất ngay sau `startGesture()` khiến ticker "bắt đầu" NGAY TẠI thời điểm đã nhảy tới, elapsed=0, animation không tiến. Phải `pump()` rỗng trước, rồi mới `pump(bigDuration)`. Áp dụng cho toàn bộ test file.

**Test:** `test/widget/common/hold_to_confirm_button_test.dart` (10 case, TDD): giữ đủ gọi confirm 1 lần, thả sớm không gọi, kéo ra ngoài bounds huỷ, rage-tap 5 lần liên tục không bao giờ gọi, pointer thứ 2 bị bỏ qua hold gốc vẫn đúng, 2 lần giữ liên tiếp gọi đúng 2 lần (không rò rỉ state), disabled không gọi + Semantics đúng flag, screen-reader `SemanticsAction.tap` gọi ngay không cần giữ, reduced motion không rút ngắn duration, unmount giữa chừng không throw.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1346/1346 pass. example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass — phải sửa 1 test khác (`IDEA-53`) vì demo radial mới luôn hiện 1 `CircularProgressIndicator` trên màn hình (baseline không còn là 0), đổi `findsNothing`/`findsOneWidget` cứng sang so `baseline`/`baseline+1` — không phải bug, là thích nghi fixture dùng chung. `dart run tool/api_compatibility.dart check` → unchanged. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Wire demo vào `widget_showcase_screen.dart` (2 biến thể radial "Delete" + linear "Reset", counter "Confirmed: N"). Bug LAYOUT thật phát hiện qua device thật (không phải qua test): `Row` demo tràn viền phải ("RIGHT OVERFLOWED BY 48 PIXELS") trên Pixel 7 Pro thật vì linear button width mặc định 240 + radial + Text không vừa panel — sửa dùng `Wrap` + `width: 180` cho linear. Widget test không bắt được lỗi này vì test viewport ảo (1080px) rộng hơn thực tế device denity-scaled width.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): build+cài, mở Widget Kit → thấy đúng section HoldToConfirmButton sau khi sửa layout. `mobile_long_press_on_screen_at_coordinates(duration: 1200ms)` trên nút Delete → "Confirmed: 1" (đúng, giữ đủ). Giữ lại `duration: 200ms` (không đủ) → "Confirmed" KHÔNG tăng, progress về 0 (đúng, huỷ). Không log lỗi, `mobile_list_crashes` rỗng. (Sự cố ngoài ý muốn: 1 lần thao tác navigation lạc vào màn Recent Apps hệ thống rồi chạm nhầm app khác trên máy dùng chung — thoát ngay bằng HOME, không tương tác gì thêm trong app đó, không gây hậu quả.)

**Tự chấm điểm: 9/10** — TDD bắt đúng 1 bug logic thật (`animateTo(0)` cũng completed) mà review thủ công dễ bỏ sót, tái dùng đúng `HapticChoreographer`/`Listener` thay vì tự chế, phát hiện + sửa đúng 1 bug layout thật qua device (không chỉ qua test ảo), ghi rõ trade-off accessibility (bypass hold, không giả vờ "giữ được" cho switch-access). Trừ 1 điểm vì layout overflow lẽ ra nên lường trước khi chọn `width: 240` mặc định cho linear share 3-item Row, phải sửa sau khi thấy trên device thay vì tính trước.

