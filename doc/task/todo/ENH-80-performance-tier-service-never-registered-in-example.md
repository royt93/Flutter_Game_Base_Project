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
- [ ] `example/lib/main.dart` đăng ký `RoyCasualKitModule.performance`.
- [ ] Có 1 khu vực demo hiển thị tier hiện tại, cập nhật reactive khi tier đổi.
- [ ] `AuroraBgLayer`/`NeonAuraLayer` trong example thật sự nhận tín hiệu từ `PerformanceTierService` đã đăng ký (không còn coi `null` là fallback "luôn tier cao").
- [ ] Test widget verify demo hiển thị đúng tier, cập nhật đúng khi tier thay đổi (mock/inject tier value).
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở `example/`.

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
