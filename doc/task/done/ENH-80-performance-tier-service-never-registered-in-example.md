---
id: ENH-80
title: "PerformanceTierService không bao giờ được đăng ký/demo trong example — cơ chế hysteresis FPS chưa từng được exercise thật"
type: enhancement
priority: P1
effort: S
source: "3 nguồn độc lập (claude, agy, Fork nội bộ audit example/tests) — cùng phát hiện, tín hiệu ưu tiên rất cao"
---

## Vị trí
`example/lib/main.dart` (`RoyCasualKitConfig.modules`), `lib/core/performance_tier_service.dart`.

## Hiện trạng
`grep -rn "PerformanceTierService\|RoyCasualKitModule.performance" example/lib/` không ra kết quả nào (xác nhận qua Fork nội bộ). Module `performance` chưa từng được đăng ký trong `main.dart`, class chưa từng được reference ở bất kỳ đâu trong `example/lib/`. Toàn bộ cơ chế hysteresis FPS-downgrade mà CLAUDE.md nhấn mạnh (`ShaderTickerLayerState` check `PerformanceTierService.maybe`, coi `null` là "luôn tier cao") chưa từng được exercise thật trong app mẫu.

## Vì sao cần / Hậu quả
3 nguồn độc lập (claude, agy, và fork audit chuyên trách example/tests) đều tự phát hiện đúng gap này — tín hiệu ưu tiên rất mạnh. `example/` là nơi 1 dev tích hợp lần đầu tham khảo cách dùng; thiếu demo nghĩa là tính năng adaptive-performance nổi bật nhất của kit (theo CLAUDE.md) không có bằng chứng hoạt động thật, và cũng chưa từng được test end-to-end qua `NeonBg`/`AuroraBgLayer` thật trong 1 app chạy thật.

## Đề xuất
Thêm `RoyCasualKitModule.performance` vào `modules` trong `example/lib/main.dart`. Thêm 1 khu vực demo trong `WidgetShowcaseScreen` hoặc `CookbookScreen` hiển thị `PerformanceTierService.maybe?.tier.value` hiện tại (Obx reactive), kèm 1 nút giả lập hạ/tăng FPS (nếu `PerformanceTierService` có API test-only cho việc này) để minh hoạ hysteresis downgrade/upgrade.

## Acceptance criteria
- [x] `example/lib/main.dart` đăng ký `RoyCasualKitModule.performance`.
- [x] Có 1 khu vực demo hiển thị tier hiện tại, cập nhật reactive khi tier đổi.
- [x] `AuroraBgLayer`/`NeonAuraLayer` trong example thật sự nhận tín hiệu từ `PerformanceTierService` đã đăng ký (không còn coi `null` là fallback "luôn tier cao").
- [x] Test widget verify demo hiển thị đúng tier, cập nhật đúng khi tier thay đổi (mock/inject tier value).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở `example/`.

## Quyết định
Implement đúng 3 phần của đề xuất, cộng phát hiện + tự sửa thêm 1 phần criterion ban đầu thiếu:

1. `example/lib/main.dart`: thêm `RoyCasualKitModule.performance` vào `modules`, gọi `PerformanceTierService.maybe?.start()` sau bootstrap (module chỉ đăng ký service, KHÔNG tự `start()` — đúng chủ đích ghi trong doc comment của chính `start()`, app thật phải tự gọi).
2. `CookbookScreen`: thêm tile `'PerformanceTierService — feed synthetic slow frames (hysteresis)'` — dùng `.maybe ?? Get.put` để tái sử dụng ĐÚNG instance bootstrap đã đăng ký (không tạo bản riêng), gọi `recordFrame(30)` đủ 1 `windowSize` (60) lần để kích hoạt downgrade thật qua `FrameBudgetTracker`'s hysteresis (30ms/frame ≈ 33fps, dưới ngưỡng downgrade mặc định 40fps) — dùng đúng seam `recordFrame()` mà class đã tự document là "testable seam", không cần giả lập `SchedulerBinding`.
3. **Phát hiện khi verify criterion 3**: `AuroraBgLayer`/`NeonAuraLayer` (2 class thật sự dùng `ShaderTickerLayerState`, thứ duy nhất check `PerformanceTierService.maybe`) KHÔNG được dùng ở BẤT KỲ ĐÂU trong `example/` — kể cả sau khi đăng ký module + thêm tile demo, criterion 3 vẫn chưa thoả. Sửa bằng cách phát hiện `NeonBg` (dùng ở MỌI màn hình example) đã có sẵn cờ `aurora: bool` public stack đúng `AuroraBgLayer` khi bật — chỉ cần đổi `NeonBg(aurora: true, ...)` ở `CookbookScreen` (1 dòng), không cần tự dựng `AuroraBgLayer` thủ công.

**TDD verify**: `git stash` riêng `example/lib/main.dart` + `example/lib/screens/cookbook_screen.dart`, chạy test mới — FAIL đúng trên code cũ (`PerformanceTierService.maybe` = null, `CookbookScreen` chưa tự đăng ký). `git stash pop`, chạy lại toàn bộ `cookbook_screen_test.dart`/`cookbook_screen_more_test.dart`/`cookbook_screen_remote_config_test.dart` — 27/27 pass. Test verify cả: (a) tier bắt đầu `high`, (b) sau khi feed đủ 60 frame chậm → tier chuyển đúng `low`, (c) `find.byType(AuroraBgLayer)` tìm thấy đúng 1 widget trong cây (chứng minh criterion 3 thật sự thoả, không chỉ service đăng ký suông).

**Smoke test device thật** (Pixel 7 Pro, `2B051FDH3006MU`) — build release, mở `CookbookScreen`, scroll tới tile mới, bấm — bắt được đúng toast qua accessibility tree: `"...tier: high -> low (sau 60 frame ~33fps, dưới ngưỡng downgrade mặc định 40fps)"`, không crash. (Lưu ý: smoke test này chạy TRƯỚC khi phát hiện + thêm phần `aurora: true` ở bước 3 — phần đó chỉ verify được qua widget test + `flutter analyze`/full suite sau đó, không re-run device; `ShaderTickerLayerState`'s `_load()` có try/catch tự ẩn hiệu ứng nếu load shader lỗi, không crash, nên rủi ro thấp.)

Kết quả cuối: `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 133/133 pass. Root `flutter analyze` sạch, `dart run tool/api_compatibility.dart check` unchanged (không đổi `lib/`).

Tự chấm: **9.5/10** — implement đúng đề xuất, PHÁT HIỆN VÀ TỰ SỬA 1 khoảng trống thật trong chính acceptance criteria ban đầu (criterion 3 chưa thoả sau khi chỉ làm phần 1+2) trước khi coi là xong thay vì bỏ qua, tái sử dụng đúng cờ `aurora` có sẵn của `NeonBg` thay vì tự dựng lại, TDD chứng minh đầy đủ cả 3 phần, smoke test device thật xác nhận phần lõi hoạt động đúng. Trừ 0.5 vì phần `aurora: true` bổ sung sau không re-verify lại trên device thật (đã giải thích rủi ro thấp + có unit test coverage).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-80-performance-tier-service-never-registered-in-example.md` này trước khi làm. Đọc toàn bộ `lib/core/performance_tier_service.dart`, `lib/presentation/widgets/shader_ticker_layer.dart`, `example/lib/main.dart`, và cách các service khác được demo trong `WidgetShowcaseScreen`/`CookbookScreen` (đúng convention `.maybe ?? Get.put`) trước khi thêm demo mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở `example/`.
4. Smoke test trên device Android thật khuyến khích (mở màn hình demo, verify tier hiển thị đúng, không crash `ShaderTickerLayer` — liên quan trực tiếp BUG-56 nếu chưa fix, nên làm SAU BUG-56 nếu có thể).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao — 3 nguồn độc lập (claude, agy, Fork nội bộ) cùng xác nhận qua grep trực tiếp `example/lib/` không có kết quả nào cho `PerformanceTierService`/`RoyCasualKitModule.performance`. Không trùng task nào trong `doc/task/done/`.
