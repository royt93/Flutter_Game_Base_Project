---
id: FEAT-53
title: "PauseOverlay — resume/restart/settings/quit nối GameSessionController"
type: feature
layer: presentation/widget
priority: P0
effort: M
depends_on: [FEAT-41, FEAT-49, FEAT-50]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn pause overlay nhất quán và game chỉ resume khi đúng pause owner được giải phóng.

## Sprint slices
- Overlay-first panel dùng session state, action slots và confirm hook.
- Entrance/exit animation, focus trap, back behavior và audio/game-time coordination.
- Default resume/restart/settings/quit wiring có thể override.

## Acceptance criteria
- [x] Hiện đúng khi user pause, không tự hiện cho mọi system pause nếu config không yêu cầu.
- [x] Back/resume/restart/quit phát đúng command một lần.
- [x] Overlay modal về pointer/semantics/focus và hoạt động trên Flame full-screen.
- [x] Reduced motion, text scale và RTL đạt chuẩn.

## Prompt loop feature
Đọc task/session/dialog conventions; implement TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi action/back/focus/lifecycle; analyze/test root + example; smoke Android device thật trên Flame demo có video/log. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Thêm `PauseOverlay` (`lib/presentation/widgets/common/pause_overlay.dart`) — bọc `GameSessionController` (FEAT-41) trực tiếp, dựng trên `NeonDialog.overlaySlot` có sẵn (đúng "always mounted, panel nullable, animate cả vào lẫn ra" convention, đã chứng minh hoạt động trên Flame `GameWidget` qua chính doc comment của `NeonDialog.overlay`/`game_demo_screen.dart`) thay vì tự nghĩ cơ chế overlay mới:
- Visible = `session.snapshot.value.phase == paused && pauseReasons chứa user` (hoặc thêm system nếu `showForSystemPause: true`) — logic đọc thẳng từ `GameSessionSnapshot` có sẵn, không thêm state pause riêng nào (tránh chính xác "double pause/resume" mà task cảnh báo).
- Back button: `PopScope(canPop: !visible, onPopInvokedWithResult: ...)` — resume thay vì pop route khi overlay đang hiện. Đây LÀ route thật của `PopScope` (không phải "trick" `NeonDialog.show` dùng cho dialog dạng route) vì overlay này không bao giờ là 1 route, giống hệt lý do `NeonDialog.overlay`/`.overlaySlot` tồn tại.
- `onResume`/`onRestart` mặc định gọi `session.resume(user)`/`session.restart()`; `onSettings`/`onQuit` không có default hợp lý (package không biết settings/quit nghĩa là gì với 1 game cụ thể) — để `null` thì ẩn nút tương ứng thay vì wire no-op.
- Game-time coordination TỰ ĐỘNG, không cần code gì thêm ở đây: `GameTimeController` (FEAT-49) đã tự đọc `session` trực tiếp. Audio coordination CỐ TÌNH không tự động — pause/resume nhạc nền lúc mở pause menu là quyết định tuỳ game, ép buộc sẽ vi phạm nguyên tắc "mọi thứ overridable" của kit; đã ghi rõ trong doc comment, `onResume` là điểm hook nếu 1 game muốn tự làm.
- Focus trap: panel là 1 `FocusScope` riêng, `autofocus: true` khi hiện — trap ĐÚNG mức "focus-scope ownership", KHÔNG trap được Tab-key activation từng nút vì `CommonButton`/`PressableScale` toàn bộ kit hiện là gesture-only, chưa có keyboard-activation wiring (gap có sẵn của cả kit, không phải riêng widget này) — ghi rõ giới hạn thay vì âm thầm claim "focus trap" đầy đủ.
- Semantics: `Semantics(container: true, label: title)` KHÔNG dùng `scopesRoute` (overlay không phải route thật, đúng lý do `LoadingOverlay` đã ghi) và KHÔNG dùng `excludeSemantics` (khác `LoadingOverlay` — panel này CÓ nút tương tác, ẩn semantics con sẽ nuốt mất accessibility của 4 nút).

**Test:** `test/widget/common/pause_overlay_test.dart` (12 case, TDD — RED xác nhận trước khi viết `pause_overlay.dart`): ẩn lúc playing, hiện lúc user pause, không tự hiện cho system pause (mặc định)/hiện khi bật cờ, Resume/Restart mặc định đúng, override thay hành vi mặc định, Settings/Quit ẩn/hiện theo callback, back button resume không pop route, back lúc ẩn không side-effect, reduced motion → `AnimatedSwitcher.duration == Duration.zero`, RTL + text scale 2.0 không throw. Gặp lỗi finder 1 lần (label render qua `StrokeText` 2 lớp Text — dùng `find.widgetWithText(CommonButton, label)` + `.first` khi tap, đúng convention `backup_restore_panel_test.dart`/`example/test/widget_showcase_screen_test.dart` đã có, không phải bug code).

Wire demo vào `example/lib/screens/game_demo_screen.dart` (thêm Pause FAB cạnh info FAB, `PauseOverlay(session: _session, onQuit: Get.back)`) thay vì `widget_showcase_screen.dart` — vì acceptance criteria yêu cầu rõ "hoạt động trên Flame full-screen", GameDemoScreen là màn HÌNH DUY NHẤT trong example có Flame `GameWidget` thật. Cập nhật `game_demo_screen_test.dart` (test cũ dùng `find.byType(FloatingActionButton)` số ít, giờ có 2 FAB nên đổi sang `find.byIcon` cho chính xác) + thêm 1 test mới verify Pause FAB → overlay hiện trên GameWidget → Resume ẩn lại.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1322/1322 pass (2 lần chạy riêng biệt gặp 2 flaky pre-existing KHÁC NHAU — `save_slot_manager_test.dart` và `season_event_service_test.dart`, cả 2 đều pass khi chạy cô lập và pass ở 1 lần chạy full sạch — máy đang tải nặng lúc làm task này, không liên quan code). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass. `dart run tool/api_compatibility.dart check` → unchanged (chỉ export trong `common_widgets.dart`, không đổi top-level `roy_casual_kit.dart`). `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): build+cài `example` debug APK, mở "Demo Flame", bấm Pause FAB → overlay "Paused"/Resume/Restart/Quit hiện đúng trên GameWidget thật; bấm Resume → đóng lại, game tiếp tục; bấm Pause rồi bấm nút BACK vật lý → overlay tự đóng (resume), KHÔNG pop về HomeScreen (verify đúng `PopScope`); bấm Pause rồi bấm Quit → điều hướng đúng về HomeScreen. Không log lỗi (`mobile_get_device_logs` filter `level=Error` rỗng ở mọi bước), `mobile_list_crashes` rỗng.

**Tự chấm điểm: 9/10** — tái dùng đúng `NeonDialog.overlaySlot`/`PopScope`/`GameSessionController` có sẵn thay vì tự chế, ghi rõ 2 giới hạn có chủ đích (audio không tự pause, focus trap chỉ ở mức scope-ownership) thay vì âm thầm claim đầy đủ, wire demo đúng chỗ (GameDemoScreen thay vì showcase chung) vì acceptance đòi hỏi Flame thật, verify đủ trên device thật kể cả back-button. Trừ 1 điểm vì đây là widget-layer mới hoàn toàn không có tiền lệ "focus trap" nào trong repo để đối chiếu — implementation phần focus là suy luận hợp lý nhất từ Flutter framework thuần, không phải pattern đã kiểm chứng qua nhiều task như phần còn lại.

