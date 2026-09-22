---
id: IDEA-63
title: "Battery Saver Mode Coordinator — tự hạ frame rate/tắt shader khi pin thấp"
type: idea
priority: low
effort: S
source: "agy (độc lập)"
---

## Vị trí
Mới, dựa trên `lib/core/performance_tier_service.dart`, `lib/presentation/widgets/shader_ticker_layer.dart`.

## Hiện trạng
`PerformanceTierService` hạ tier dựa trên FPS thực đo (hysteresis), nhưng không lắng nghe mức pin thiết bị — 1 thiết bị đang chạy mượt (FPS cao) nhưng pin yếu vẫn tiếp tục chạy shader/hiệu ứng nặng.

## Vì sao cần / Hậu quả
Chủ động hạ tải khi pin thấp (thay vì chỉ phản ứng khi FPS đã tụt) giúp máy đỡ nóng/tiết kiệm pin hơn cho phiên chơi dài.

## Đề xuất
Thêm 1 coordinator lắng nghe mức pin (qua `battery_plus` hoặc plugin tương tự — cân nhắc kỹ ponytail: chỉ thêm dependency mới nếu thật sự cần, kiểm tra platform channel có sẵn trước), khi pin < ngưỡng (ví dụ 20%) ép `PerformanceTierService` xuống `low` bất kể FPS thực đo.

## Acceptance criteria
- [ ] Pin dưới ngưỡng cấu hình — `PerformanceTierService.tier` bị ép xuống `low`.
- [ ] Pin trên ngưỡng — không ép buộc, để `PerformanceTierService` tự quyết theo FPS như bình thường.
- [ ] Test unit cho logic ép tier theo pin (mock battery level).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-63-battery-saver-mode-coordinator.md` này trước khi làm. Đọc toàn bộ `lib/core/performance_tier_service.dart` và `pubspec.yaml` (kiểm tra có dependency đọc pin nào sẵn có chưa, cân nhắc kỹ trước khi thêm dependency mới) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật khuyến khích (verify hành vi khi pin thấp thật, nếu tiện) không bắt buộc nếu unit test với mock battery level đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hợp lý, cần thêm dependency mới (đọc mức pin) — cân nhắc kỹ giá trị/effort trước khi implement, ponytail nhắc: chỉ thêm khi thật cần. Không trùng task nào trong `doc/task/done/`.
