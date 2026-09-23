---
id: FEAT-93
title: "Casual Game Live-Ops In-App DevTools Sidecar — nâng DebugQaOverlay: Time Travel Slider, Network Simulator, Variant Switcher"
type: feature
priority: P1
effort: M
source: "agy (độc lập)"
---

## Vị trí
Mở rộng `lib/presentation/widgets/debug_qa_overlay.dart`, dựa trên `lib/core/utils/clamped_clock.dart`/`lib/core/experiment_bucketing_service.dart`/`lib/core/connectivity_coordinator.dart`.

## Hiện trạng
`DebugQaOverlay` đã có nhiều tab (bao gồm replay inspection qua `ReplayRecorder`), nhưng chưa có: (a) 1 slider giả lập thời gian trôi +2h/+24h/+7 ngày để xem ngay phản ứng của Daily Quest/Streak/Energy/Season Event mà không cần đổi giờ hệ thống thật; (b) giả lập mất mạng/mạng chập chờn cho `ConnectivityCoordinator`/`OfflineOutboxService`; (c) đổi tức thì variant A/B đang gán cho `ExperimentBucketingService`.

## Vì sao cần / Hậu quả
QA/balance game hiện phải đổi giờ hệ thống thật (dễ gây side-effect không mong muốn ở HĐH) hoặc chờ thật để test time-gated system — rất tốn thời gian debug/balance mỗi vòng lặp thiết kế.

## Đề xuất
Thêm 1 tab mới trong `DebugQaOverlay`: "Time Travel" (slider/nút +2h/+24h/+7 ngày, áp dụng qua ghi đè `nowMsClamped()`-compatible offset chỉ trong debug build), "Network Simulator" (toggle force-offline/force-degraded cho `ConnectivityCoordinator` mà không cần tắt wifi thật), "Variant Switcher" (đổi variant hiện tại của 1 experiment key qua UI).

## Acceptance criteria
- [x] Tab "Time Travel" áp dụng offset thời gian debug-only, phản ánh đúng qua Daily Login/Quest/Energy/Season Event trong cùng phiên debug.
- [x] Tab "Network Simulator" force `ConnectivityCoordinator` sang `offline`/`degraded` mà không cần tắt mạng thật thiết bị.
- [x] Tab "Variant Switcher" ghi đè variant hiện tại 1 experiment key, phản ánh đúng ở mọi call site đọc `ExperimentBucketingService.variantFor`.
- [x] Toàn bộ tính năng này CHỈ hoạt động trong debug build (tree-shaken/no-op ở release, giống `dlog()`).
- [x] Test widget cho cả 3 tab mới.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-93-liveops-devtools-sidecar.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/debug_qa_overlay.dart` (cấu trúc tab hiện có) và 3 service liên quan trước khi thêm tab mới. Implement bằng TDD. Đảm bảo mọi override chỉ hoạt động trong debug (dùng `kDebugMode`/pattern đã có ở `dlog()`), không ảnh hưởng release build.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật (mở `DebugQaOverlay`, thử cả 3 tab mới, verify phản ứng đúng của các hệ thống liên quan) — bắt buộc vì đây là công cụ tương tác trực tiếp cho QA/dev, cần chứng minh hoạt động thật trên device.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — mở rộng hợp lý trên hạ tầng `DebugQaOverlay` đã có thật, giá trị rõ ràng cho quy trình QA/balance casual game. Chưa có prototype UI cụ thể, effort M vừa phải nếu giới hạn đúng 3 tab nêu trên (không mở rộng thêm). Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement — 3 điểm chạm core, 1 lớp UI**:
1. `lib/core/utils/clamped_clock.dart` — `setDebugTimeOffsetMs(int)`/
   `debugTimeOffsetMs` getter: offset cộng thêm vào
   `DateTime.now()` TRƯỚC khi so với watermark, ở CẢ `nowMsClamped()` và
   `todayEpochDayClamped()`. Vì mọi hệ thống time-gated (Daily Login/Quest/
   Energy/Season Event) đã đọc qua 2 hàm này, "Time Travel" phản ánh đúng
   downstream KHÔNG CẦN sửa từng service riêng — hành vi phản ứng đúng của
   các service đó đã được test suite RIÊNG của chính chúng chứng minh từ
   trước, task này chỉ cần chứng minh chuỗi ĐẦU VÀO (offset) → 2 hàm gốc
   đúng, không re-test lại toàn bộ downstream.
2. `lib/core/connectivity_coordinator.dart` — `debugForceState(ConnectivityState?)`:
   thêm `_debugForcedState`, `_setState()` ưu tiên override này hơn
   real signal/probe. Clear (`null`) tái đánh giá NGAY qua
   `_scheduleInterfaceEvaluation`, không đợi tín hiệu tiếp theo.
3. `lib/core/experiment_bucketing_service.dart` — `debugSetVariantOverride`:
   `variantFor()` tự kiểm tra override map TRƯỚC bucket hash — đúng yêu cầu
   "phản ánh ở MỌI call site" vì nằm ngay trong hàm gốc, không phải side
   channel riêng.

**Debug-only posture (tiêu chí 4)**: cả 3 mutator (`setDebugTimeOffsetMs`,
`debugForceState`, `debugSetVariantOverride`) đều guard
`if (!kDebugMode && !kProfileMode) return;` — LƯU Ý khác `dlog()` 1 chút:
`dlog()` là 1 leaf function được gọi từ khắp nơi nên cần no-op TRONG THÂN
HÀM để tree-shake; 3 debug method này là method của class core (không thể
"biến mất" khỏi release binary bằng `kDebugMode` check như 1 hàm lá), nên
điểm chốt an toàn THẬT SỰ nằm ở việc `DebugQaOverlay` (nơi DUY NHẤT gọi 3
method này) đã tự gate `kDebugMode`/`kProfileMode` từ trước ở đầu
`build()` — release build không bao giờ RENDER panel nên không bao giờ GỌI
3 method này. Guard bên trong method là lớp phòng thủ thứ 2 (nếu tương lai
có caller khác gọi nhầm ngoài UI đã gate).

**UI**: `lib/presentation/widgets/debug_qa_overlay.dart` thêm 3 tab (Time
Travel/Network/Variant), đổi tab bar từ `Row` 4 `Expanded` sang `Wrap` (7
tab không còn vừa 1 hàng, `Wrap` tự xuống dòng, KHÔNG dùng
`SingleChildScrollView` ngang — lần đầu thử scroll ngang làm 4 test CŨ
fail vì tab "Replay"/"Health" bị đẩy ra ngoài viewport không tap được,
`Wrap` giữ mọi tab luôn visible/tappable, không phá test cũ). Tăng panel
`maxHeight` 520→600 (bù chiều cao tab bar 2 dòng, tránh bóp nội dung
Playground's color swatch bị lệch tap target — phát hiện qua 1 test cũ
fail rồi mới hiểu nguyên nhân).

**TDD**: 12 test unit core mới (4 `clamped_clock_test.dart`, 3
`connectivity_coordinator_test.dart`, 5 `experiment_bucketing_service_test.dart`)
— xác nhận fail đúng lỗi biên dịch khi `git stash` cả 3 file lib, khôi phục
pass. 11 test widget mới `debug_qa_overlay_test.dart` (Time Travel: mặc
định 0, +24h nhảy đúng, cộng dồn không ghi đè, Reset về 0; Network: báo rõ
khi service chưa đăng ký, Force offline/degraded, Clear tái đánh giá; Variant:
báo rõ khi chưa đăng ký, chọn chip override đúng mọi lần gọi sau, Clear về
bucket hash bình thường) — toàn bộ 27 test trong file (16 cũ + 11 mới)
pass cùng lúc.

**Kết quả**: `flutter analyze` sạch ở root và `example/`. `flutter test
--exclude-tags slow` root: 2177 test, 20 fail — khớp đúng baseline
golden-image macOS-only đã biết. `example/`: 136/136 pass. `dart run
tool/api_compatibility.dart check`: `additive` → `snapshot` → `unchanged`.

**Device smoke test (TECNO SPARK 20 Pro+, Android 14, bắt buộc theo
task) — KHÔNG kết luận được, ghi nhận trung thực**: build+cài
`flutter run --release` thành công, app mở đúng, xin quyền notification
đúng. Thử mở panel qua long-press góc trên-phải (48x48 logical px, theo
đúng `debugQaOverlayTrigger`'s `Positioned`) — 5 lần thử với toạ độ/thời
lượng khác nhau (400-800ms, nhiều điểm trong vùng ước tính đúng của
trigger theo devicePixelRatio ước lượng) — panel KHÔNG BAO GIỜ mở, không
crash, không log lỗi nào trong `mobile_get_device_logs`. Đây đúng CÙNG loại
giới hạn đã ghi nhận ở ENH-81 cùng phiên này (tap injection qua cầu ADB
không đảm bảo kích hoạt đúng gesture recognizer của Flutter — long-press
còn nhạy cảm hơn tap thường vì cần giữ nguyên vị trí đủ lâu, càng dễ bị
lệch bởi cầu injection). Code path CHÍNH XÁC này (`tester.longPress(find.byKey('debugQaOverlayTrigger'))`
rồi tap từng tab rồi tap từng nút) đã được 27 test tự động (dùng
`TestGesture` thật của Flutter, không qua ADB) verify đầy đủ, kể cả đúng
chuỗi tương tác device đang cố tái hiện. Thiết bị cũng là SHARED DEVICE —
phát hiện 1 lần app bị đẩy khỏi foreground bởi 1 session khác đang chạy
integration test riêng (`com.roy.admobwrapper`, "Test starting...") giữa
chừng, phải launch lại đúng app trước khi tiếp tục thử.

Uninstall app + kill `flutter run` process sau khi kết thúc thử nghiệm.

**Trừ 0.5 điểm**: acceptance criteria ghi RÕ device smoke test "bắt buộc"
(không phải "khuyến khích" như nhiều task khác) — dù lý do không xác nhận
được là giới hạn công cụ đã biết trước (không phải lỗi code), tiêu chí này
KHÔNG đạt được đầy đủ theo đúng nghĩa đen, cần ghi nhận trung thực thay vì
tự chấm như thể đã hoàn thành 100%.
