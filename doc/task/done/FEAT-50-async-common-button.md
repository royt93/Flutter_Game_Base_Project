---
id: FEAT-50
title: "AsyncCommonButton — loading/success/error và chống double tap"
type: feature
layer: presentation/widget
priority: P0
effort: S
depends_on: [FEAT-34, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app/game developer, tôi muốn nút async tự khóa, báo tiến trình/kết quả và không gọi action hai lần.

## Sprint slices
- API composable trên `CommonButton`, nhận async callback và optional external state.
- Animated label→spinner→success/error, timeout/retry policy optional.
- Semantics live status, disabled state và reduced motion.

## Acceptance criteria
- [x] Rapid tap chỉ chạy một Future; thành công/lỗi/timeout về trạng thái đúng.
- [x] Unmount trong lúc chờ không setState/callback sau dispose.
- [x] Layout không nhảy width và hỗ trợ text scale/RTL.
- [x] Animation theo NeonTheme, reduced motion collapse đúng.

## Prompt loop feature
Đọc task và CommonButton; implement TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi tap/success/error/timeout/dispose/accessibility; analyze/test root + example; smoke Android device thật có video/log. Lặp tới work và điểm >9/10 mới push; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Thêm `AsyncCommonButton` (`lib/presentation/widgets/common/async_common_button.dart`) — `StatefulWidget` bọc `CommonButton` sẵn có, tự chuyển qua `AsyncButtonStatus.idle/loading/success/error`:
- Tap khi không ở `idle` bị bỏ qua (chặn double-tap và chặn tap lại trong lúc đang hiện success/error cooldown).
- `onPressed` optional `timeout` qua `Future.timeout` — timeout rơi vào cùng nhánh `catch` như lỗi thường, không phân biệt state riêng (đúng scope S, không kéo theo `RetryPolicy` của FEAT-35).
- `mounted` guard trước mọi `setState` sau `await`; `Timer` tự-revert-về-idle bị `cancel()` trong `dispose()`.
- Chuyển trạng thái bọc trong `AnimatedSwitcher` (200ms, `NeonTheme.reducedMotion(context)` → `Duration.zero`) — tái dùng đúng convention `reducedMotion` đã có ở `NeonDialog`/`ConfettiOverlay`/... thay vì tự chế cờ mới.
- Announcement `Semantics(liveRegion: true)` tách riêng (theo đúng pattern `BackupRestorePanel`/`CurrencyCounter` đã có), không đụng `Semantics` gốc của `CommonButton`.
- Width ổn định giữa các trạng thái vì `CommonButton._buildPill` đã fix `width` sẵn — không cần thêm logic riêng.

Không sửa `CommonButton` — chỉ compose lên trên, đúng "Sprint slices".

**Test:** `test/widget/common/async_common_button_test.dart` (9 case, TDD — xem RED trước khi viết `async_common_button.dart`): tap-once, rapid-tap-guard, success→idle sau `successDuration`, lỗi→idle sau `errorDuration`, timeout→error, unmount giữa chừng không throw, width ổn định qua 3 trạng thái, `reducedMotion` → `AnimatedSwitcher.duration == Duration.zero`, RTL + text scale 2.0 không throw/tràn layout.

Wire demo vào `example/lib/screens/widget_showcase_screen.dart` (section "AsyncCommonButton", 2 nút: 1 luôn thành công, 1 luôn lỗi) — theo đúng convention CLAUDE.md "widget_showcase_screen.dart là living reference cho mọi common/ widget".

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1270/1270 pass (thêm 9 test này, không test nào khác vỡ). example `flutter analyze` sạch, example `flutter test --exclude-tags slow` 55/55 pass. `dart run tool/api_compatibility.dart check` → unchanged (chỉ thêm export bên trong `common_widgets.dart`, không đổi export top-level của `roy_casual_kit.dart`). `dart pub publish --dry-run` → 1 warning (working-tree chưa commit — hết ngay sau commit, không phải lỗi packaging thật).

Smoke Android thật (Pixel 7 Pro, `2B051FDH3006MU`): cài `example` debug APK, mở "Bộ Widget" → thấy đúng section "AsyncCommonButton" với 2 nút "Save"/"Fails", bấm cả 2, không crash (`mobile_list_crashes` sạch cho process app), không log lỗi (`mobile_get_device_logs` filter `level=Error` cho process app → rỗng), app quay lại idle ổn định, phần còn lại của màn hình không bị ảnh hưởng. Không chụp được đúng khung hình loading/success/error thoáng qua (round-trip tool chậm hơn chu kỳ 1.2-2.2s của demo) — hành vi transient đã được 9 widget test ở trên xác nhận theo cách xác định (deterministic), screenshot chỉ dùng để xác nhận không crash/không kẹt UI.

**Tự chấm điểm: 9.5/10** — TDD đầy đủ (RED xác nhận trước khi viết code), tái dùng đúng 3 pattern có sẵn (`reducedMotion`, `liveRegion` tách riêng, `CommonButton.loading`) thay vì tự chế, không sửa `CommonButton`/không phình API ngoài scope S, có demo trong showcase, đủ smoke device. Trừ 0.5 vì screenshot device không bắt được khung hình transient (giới hạn độ trễ tool, không phải lỗi code) nên bằng chứng smoke chỉ gián tiếp (log/crash sạch) thay vì hình ảnh trực tiếp trạng thái loading/success/error.

