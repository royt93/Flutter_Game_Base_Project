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
- [ ] Tab "Time Travel" áp dụng offset thời gian debug-only, phản ánh đúng qua Daily Login/Quest/Energy/Season Event trong cùng phiên debug.
- [ ] Tab "Network Simulator" force `ConnectivityCoordinator` sang `offline`/`degraded` mà không cần tắt mạng thật thiết bị.
- [ ] Tab "Variant Switcher" ghi đè variant hiện tại 1 experiment key, phản ánh đúng ở mọi call site đọc `ExperimentBucketingService.variantFor`.
- [ ] Toàn bộ tính năng này CHỈ hoạt động trong debug build (tree-shaken/no-op ở release, giống `dlog()`).
- [ ] Test widget cho cả 3 tab mới.

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
