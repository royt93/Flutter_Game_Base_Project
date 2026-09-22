---
id: IDEA-58
title: "FeatureFlagOverridePanel — tab trong DebugQaOverlay để QA tự bật/tắt RemoteKillSwitchController khi test"
type: idea
priority: low
effort: S
source: "Fork nội bộ (brainstorm task/tính năng mới)"
---

## Vị trí
Mở rộng `lib/presentation/widgets/debug_qa_overlay.dart`, dựa trên `lib/core/remote_kill_switch_controller.dart`, `lib/core/remote_config_service.dart`.

## Hiện trạng
`RemoteKillSwitchController`/`RemoteConfigService` đã có nhưng không có UI nào trong `DebugQaOverlay` để QA tự bật/tắt kill-switch khi test — hiện chỉ gọi được bằng code (QA phải nhờ dev viết code test riêng mỗi lần).

## Vì sao cần / Hậu quả
QA cần thử nghiệm hành vi app khi 1 feature bị kill mà không cần chờ dev viết code — tăng tốc chu trình test trước khi release 1 remote-config thay đổi thật.

## Đề xuất
Thêm 1 tab nhỏ trong `DebugQaOverlay` liệt kê các feature flag hiện có (từ `RemoteKillSwitchController`), cho phép toggle qua UI (chỉ trong debug build).

## Acceptance criteria
- [ ] Tab hiển thị đúng danh sách feature flag hiện có.
- [ ] Toggle qua UI phản ánh đúng vào `RemoteKillSwitchController.isKilled(featureId)`.
- [ ] Chỉ hoạt động ở debug build.
- [ ] Test widget cho tab mới.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-58-feature-flag-override-panel-debug-qa-overlay.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/debug_qa_overlay.dart` và `lib/core/remote_kill_switch_controller.dart` trước khi thêm tab. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh cho 1 tab debug UI đơn giản).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng hợp lý dựa trên hạ tầng đã có, giá trị thấp hơn các FEAT khác (chỉ là 1 tab UI tiện lợi, không phải service mới). Không trùng task nào trong `doc/task/done/`.
