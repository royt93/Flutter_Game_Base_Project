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

- [x] 1. Liệt kê ma trận (thành phần × kiểu ngắt) trong "Kết quả thực hiện", đánh dấu ô nào đã có test, ô nào thiếu; chỉ viết test cho ô thiếu.
- [x] 2. Viết test host cho các ô thiếu (đỏ trước khi sửa nếu lộ lỗi; lỗi thật tạo task BUG riêng, không sửa lẫn).
- [x] 3. Test "kill giữa lúc ghi": giữ một `setString` bằng cổng, "kill" (bỏ instance, tạo `StorageService` mới trên cùng prefs), xác nhận bản ghi không-buffered đã hoàn tất không mất, bản chưa hoàn tất không làm hỏng giá trị cũ.
- [x] 4. Mutation check cho từng test mới.
- [x] 5. Integration test emulator: viết trong `example/integration_test/interruption_test.dart`, chạy tay trên S24U/emulator bằng `flutter test integration_test/interruption_test.dart -d <thiết bị> --dart-define=E2E_TEST=true`; ghi kết quả vào `docs/qa/device_matrix.md`. Phần đưa vào workflow lịch tuần: hỏi owner trước khi sửa `ci.yml`.
- [x] 6. Cổng cuối: `flutter analyze`, `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation`, `dart run tool/api_compatibility.dart check`, 5 tool quality-gate. Ghi kết quả, chuyển sang `doc/task/done/`.

## Tiêu chí nghiệm thu

- [x] Ma trận thành phần × kiểu ngắt có trong task, mọi ô đã có test hoặc có lý do loại.
- [x] Không mất dữ liệu đã ghi unbuffered qua kill mô phỏng.
- [x] Integration test chạy được trên thiết bị (TECNO KJ7, KHÔNG phải S24U) và kết quả được ghi vào docs/qa; chưa chạy trên S24U.

## Lệnh kiểm chứng nhanh

- `flutter test test/core/lifecycle_coordinator_test.dart test/core/game_session_controller_test.dart test/core/checkpoint_coordinator_test.dart`

## Kết quả thực hiện (2026-11-24)

### Ma trận thành phần x kiểu ngắt

| Thành phần | Kiểu ngắt | Trước | Sau |
| --- | --- | --- | --- |
| `GameSessionController` + lifecycle | background một lần / resume | có (`game_session_controller_test`) | giữ nguyên |
| | resume KHÔNG có pause trước | thiếu | `interruption_test` |
| | 5 vòng background/foreground liên tiếp | thiếu | `interruption_test` + máy thật |
| | `inactive`>`hidden`>`paused` là MỘT pause | thiếu (chỉ `paused`/`inactive` hai lần) | `interruption_test` + máy thật |
| | pause của người chơi sống qua vòng background | thiếu | `interruption_test` + máy thật |
| | `detached` rồi resume muộn | thiếu (chỉ coordinator) | `interruption_test` |
| | ván đã `won` rồi background/resume | thiếu | `interruption_test` |
| | controller bị dispose lúc đang nền, resume sau | thiếu | `interruption_test` |
| `GameSessionEngineBridge` | background/resume tạm dừng engine | có (`game_session_engine_bridge_test`) | giữ nguyên |
| `RoyLifecycleCoordinator` | `detached`, hook lỗi/timeout, flush lỗi, trim memory | có (`lifecycle_coordinator_test`) | giữ nguyên |
| `CheckpointCoordinator` | background kích hoạt flush | có | giữ nguyên |
| | kill giữa lúc commit (dirty flag, bản cũ còn) | thiếu | `interruption_test` |
| | kill SAU khi ghi hỏng current: khôi phục từ `_prev` | thiếu | `interruption_test` |
| | commit xong rồi kill: KHÔNG báo dirty | thiếu | `interruption_test` |
| `StorageService` | ghi unbuffered hoàn tất sống qua kill; ghi chưa chạy giữ giá trị cũ | thiếu | `interruption_test` |
| | ghi buffered chưa flush mất khi kill (đánh đổi đã ghi) | thiếu | `interruption_test` |
| | vào background flush buffer nên kill ngay sau không mất | thiếu | `interruption_test` |
| Match-3 màn thật | lifecycle thật, đa vòng | thiếu | `example/integration_test/interruption_test.dart` (TECNO) |
| | xoay màn hình giữa ván | thiếu | cùng file, chỉ khẳng định KHÔNG ném ngoại lệ |
| | cuộc gọi thật, kill tiến trình thật | không làm được tự động | loại: cần thao tác tay; ghi rõ trong `docs/qa` |

### Số liệu

- `test/core/interruption_test.dart`: 13 test, tất cả xanh. Test host không phát hiện bug lib nào (không có BUG mới).
- Mutation (8 biến đổi lib, cả 8 bị ít nhất một test bắt): đảo resume thành pause (6 test đỏ), resume xoá mọi lý do pause (1), bỏ flush khi vào nền (1), bỏ bản sao `_prev` (1), bỏ fallback `_prev` khi restore (1), không bao giờ ghi dirty (1), flush không ghi (1), không bao giờ xoá dirty (1). Hai mutant sống sót lúc đầu: bỏ bản sao `_prev` (không test nào đọc `_prev`) và không bao giờ xoá dirty. Hai test thêm sau đó ("kill SAU khi ghi hỏng current: khôi phục từ `_prev`" và "commit xong rồi kill: KHÔNG báo dirty") giết cả hai. Lib đã khôi phục (`cmp` giống hệt).
- Máy thật (TECNO KJ7, Android 14): 5 vòng background/foreground, `inactive>hidden>paused`, pause người chơi qua vòng: tất cả đúng; pause ~52ms, resume 0-1ms, 0 lỗi hook. Log: `doc/task/evidence/ENH-124-interruption-device.log`, dòng mới trong `docs/qa/device_matrix.md`.
- Cổng cuối: `flutter analyze` (root và `example`) sạch; `flutter test --exclude-tags slow test/widget/common test/core test/tool test/presentation` 4196 pass (trước 4183: +13); `api_compatibility check` unchanged; 5 quality-gate sạch.

### Phát hiện khi chạy máy thật (đáng ghi)

- Lần chạy đầu treo ~10 phút: khi ở nền, binding ngừng dựng frame nên `tester.pump` chờ mãi. Test thiết bị chờ bằng thời gian thực khi gửi `paused`/`inactive`.
- Sau khi mở màn Match-3 trên máy thật, `WidgetsBinding.lifecycleState` là `inactive` và coordinator đã `background` (hộp thoại/tiêu điểm hệ thống), nên `paused` đầu tiên của test bị coordinator bỏ qua (`_lastDispatched == next`, đúng thiết kế). Test giờ gửi `resumed` trước vòng 1 và in trạng thái trước đó. Chưa rõ nguyên nhân `inactive` (không điều tra: không phải lỗi lib).
- Lần đỏ thứ hai do chính test: nút `match3_pause` bị tutorial che (đánh dấu "đã xem" không ngăn màn hiện tutorial); test đi qua tutorial như `match3_game_flow_test`.

### Hạn chế (ghi rõ chưa chứng minh)

- Chưa chạy trên S24U (chỉ có TECNO cắm; owner chọn chạy TECNO). Kết quả ghi dưới nhãn TECNO.
- Bước xoay màn hình chỉ khẳng định không có ngoại lệ, không kiểm tra bố cục.
- Không kill tiến trình thật và không có cuộc gọi thật: "kill" ở test host là bỏ instance rồi dựng `StorageService` mới trên cùng `SharedPreferences`.
- Chưa đưa test vào workflow lịch tuần (cần owner đồng ý sửa `ci.yml`).
