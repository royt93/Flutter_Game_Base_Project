---
id: FEAT-94
title: "PlayerDataRightsService — export/xoá toàn bộ dữ liệu người chơi kèm biên nhận (GDPR/CCPA-style)"
type: feature
priority: P1
effort: M
source: "codex (độc lập)"
---

## Vị trí
Mới — dựa trên `lib/core/storage_service.dart` (`exportAll`/`eraseAll` đã có), `lib/core/consent_state_service.dart`.

## Hiện trạng
`StorageService` đã có `exportAll()`/`eraseAll()` ở tầng kỹ thuật thấp, nhưng không có 1 luồng nghiệp vụ hoàn chỉnh "người chơi yêu cầu xuất/xoá toàn bộ dữ liệu của họ" kèm xác nhận/biên nhận rõ ràng (timestamp, những gì đã xoá, xác nhận hoàn tất) — dạng yêu cầu ngày càng phổ biến theo quy định bảo vệ dữ liệu (GDPR/CCPA) mà game phát hành quốc tế cần đáp ứng.

## Vì sao cần / Hậu quả
Thiếu luồng chuẩn khiến mỗi consumer app phải tự lắp ráp `exportAll`/`eraseAll` với UI/xác nhận riêng — dễ thiếu sót (ví dụ quên xoá 1 phần dữ liệu liên quan analytics/crash reporter bên ngoài `StorageService`).

## Đề xuất
Thêm `PlayerDataRightsService.requestExport()` (trả file JSON kèm metadata: thời điểm, phiên bản schema) và `PlayerDataRightsService.requestErasure()` (gọi `eraseAll()` + phát 1 event cho các seam khác — `AnalyticsProvider`/`CrashReporter` — có cơ hội xoá dữ liệu phía họ, trả về 1 "biên nhận" xác nhận hoàn tất kèm timestamp).

## Acceptance criteria
- [ ] `requestExport()` trả file JSON đầy đủ dữ liệu người chơi + metadata rõ ràng.
- [ ] `requestErasure()` xoá đúng toàn bộ storage VÀ phát tín hiệu cho seam khác biết (không ép buộc, chỉ best-effort thông báo).
- [ ] Trả về 1 "biên nhận" (record) xác nhận hoàn tất, có timestamp.
- [ ] Test unit đầy đủ, demo trong `example/` (nút "Yêu cầu xuất dữ liệu"/"Yêu cầu xoá dữ liệu" trong `SettingsScreen`).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-94-player-data-rights-workflow.md` này trước khi làm. Đọc toàn bộ `lib/core/storage_service.dart` (`exportAll`/`eraseAll`), `lib/core/analytics_provider.dart`, `lib/core/crash_reporter.dart` (seam có thể cần thông báo) trước khi thiết kế service mới. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device thật khuyến khích (demo trong `SettingsScreen`, verify export/xoá hoạt động đúng) không bắt buộc nếu widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — nhu cầu thật (compliance) hợp lý cho 1 kit hướng tới phát hành quốc tế, dựa trên hạ tầng đã có sẵn (`exportAll`/`eraseAll`). Không trùng task nào trong `doc/task/done/`.
