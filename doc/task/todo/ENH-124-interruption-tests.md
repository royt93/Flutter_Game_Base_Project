---
id: ENH-124
title: "Interruption test: app vào nền/quay lại, trim memory, kill giữa lúc ghi, cuộc gọi/overlay hệ thống"
type: enhancement
layer: test/core + test/presentation + example/integration_test
priority: P3
effort: M
source: "Owner yêu cầu 2026-11-23: bổ sung các loại test để chứng minh mọi case"
---

## Bối cảnh đã đo (2026-11-23)

- Đã có test vòng đời ở mức service: `lifecycle_coordinator_test.dart` (12 mục tham chiếu `AppLifecycleState`), `game_session_controller_test.dart` (6), `checkpoint_coordinator_test.dart` (1), `app_session_tracker_test.dart`, ba widget test (`prestige_confirmation_card`, `weekly_challenge_card`, `win_streak_flame_hud`) và `example/integration_test/d4_perf_memory_test.dart` (đếm `onTrimMemory`).
- Chỉ mô phỏng sự kiện vòng đời; chưa có test: kill tiến trình giữa lúc ghi (write-behind buffer `setIntBuffered` mất khi kill: đã ghi trong doc là chấp nhận, nhưng chưa có test xác nhận bản ghi KHÔNG-buffered không mất), cuộc gọi/overlay hệ thống giữa ván Match-3, xoay màn hình giữa ván.
- Owner chọn: logic interruption chạy host/emulator (lịch tuần), không đòi máy thật.

## Phạm vi

1. **Host:** các tình huống ngắt cho từng service/engine quan trọng (`GameSessionController` + `RoyLifecycleCoordinator` + `GameSessionEngineBridge` + Match-3 màn): pause→resume nhiều lần liên tiếp, resume không có pause, `inactive` rồi `detached`, ngắt trong lúc ghi (dùng `_GatedStorageService` kiểu `season_event_service_test.dart` để giữ một lượt ghi giữa chừng rồi "kill").
2. **Emulator/lịch tuần:** một integration test trong `example/integration_test/` gửi `AppLifecycleState` thật qua `tester.binding.handleAppLifecycleStateChanged` và xoay màn hình; chỉ chạy tay hoặc theo lịch, KHÔNG trong push CI. Lưu ý `consumer-smoke` hiện chỉ chạy `integration_test/app_boot_test.dart` của app sinh ra (xem `ci.yml`), nên thêm bước chạy test này vào job tuần là một thay đổi workflow riêng cần owner đồng ý.

## Các bước (mỗi bước một commit, tick khi xong)

- [ ] 1. Liệt kê ma trận (thành phần × kiểu ngắt) trong "Kết quả thực hiện", đánh dấu ô nào đã có test, ô nào thiếu; chỉ viết test cho ô thiếu.
- [ ] 2. Viết test host cho các ô thiếu (đỏ trước khi sửa nếu lộ lỗi; lỗi thật tạo task BUG riêng, không sửa lẫn).
- [ ] 3. Test "kill giữa lúc ghi": giữ một `setString` bằng cổng, "kill" (bỏ instance, tạo `StorageService` mới trên cùng prefs), xác nhận bản ghi không-buffered đã hoàn tất không mất, bản chưa hoàn tất không làm hỏng giá trị cũ.
- [ ] 4. Mutation check cho từng test mới.
- [ ] 5. Integration test emulator: viết trong `example/integration_test/interruption_test.dart`, chạy tay trên S24U/emulator bằng `flutter test integration_test/interruption_test.dart -d <thiết bị> --dart-define=E2E_TEST=true`; ghi kết quả vào `docs/qa/device_matrix.md`. Phần đưa vào workflow lịch tuần: hỏi owner trước khi sửa `ci.yml`.
- [ ] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [ ] Ma trận thành phần × kiểu ngắt có trong task, mọi ô đã có test hoặc có lý do loại.
- [ ] Không mất dữ liệu đã ghi unbuffered qua kill mô phỏng.
- [ ] Integration test chạy được trên thiết bị và kết quả được ghi vào docs/qa (hoặc ghi rõ chưa chạy).

## Lệnh kiểm chứng nhanh

- `flutter test test/core/lifecycle_coordinator_test.dart test/core/game_session_controller_test.dart test/core/checkpoint_coordinator_test.dart`
